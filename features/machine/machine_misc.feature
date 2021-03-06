Feature: Machine misc features testing

  # @author miyadav@redhat.com
  # @case_id OCP-34940
  @admin
  @destructive
  Scenario: PVCs can still be provisioned after the password has been changed vSphere
    Given I have an IPI deployment
    Then I switch to cluster admin pseudo user

    When I run the :get admin command with:
      | resource      | secret        |
      | resource_name | vsphere-creds |
      | n             | kube-system   |
      | o             | yaml          |
   And I save the output to file> vsphere-creds_original.yaml
   Then the "vsphere-creds" secret is recreated by admin in the "kube-system" project after scenario

   Given I obtain test data file "cloud/misc/vsphere-creds_test.yaml"
   Then I run the :replace admin command with:
      | _tool | oc                       |
      | f     | vsphere-creds_test.yaml  |
   Then the step should succeed

   Given I use the "openshift-config" project
   When as admin I successfully merge patch resource "cm/cloud-provider-config" with:
     |  {"data": {"immutable": "false"}} |

   Then I use the "openshift-machine-api" project
   When 240 seconds have passed

   Then I obtain test data file "cloud/misc/PVC.yaml"
   And I run oc create over "PVC.yaml" replacing paths:
     | n | openshift-machine-api |
   Then the step should succeed
   And admin ensures "pvc" pvc is deleted after scenario

   Given I obtain test data file "cloud/misc/nginx-pod.yaml"
   When I run oc create over "nginx-pod.yaml" replacing paths:
     | n | openshift-machine-api |
   And admin ensures "mypod" pod is deleted after scenario

   Then I get project events
   And the output should match:
     | Failed to provision volume with StorageClass "thin": ServerFaultCode: Cannot complete login |

   Then I run the :replace admin command with:
      | _tool | oc                           |
      | f     | vsphere-creds_original.yaml  |
      | force |                              |
   And the step should succeed

   Then I get project events
   And the output should match:
     | Successfully provisioned volume |

  # @author miyadav@redhat.com
  # @case_id OCP-35454
  @admin
  @destructive
  Scenario: Reconciliation of MutatingWebhookConfiguration values should happen
    Given I switch to cluster admin pseudo user

    Given I use the "openshift-cluster-version" project
    Then I run the :scale admin command with:
      | resource | deployment               |
      | name     | cluster-version-operator |
      | replicas | 0                        |
    And the step should succeed
    And admin ensures the deployment replicas is restored to "1" in "openshift-cluster-version" for "cluster-version-operator" after scenario

    Given I use the "openshift-machine-api" project
    Then I run the :scale admin command with:
      | resource | deployment           |
      | name     | machine-api-operator |
      | replicas | 0                    |
    And the step should succeed
    And admin ensures the deployment replicas is restored to "1" in "openshift-machine-api" for "machine-api-operator" after scenario

    When I run the :patch admin command with:
      | resource      | MutatingWebhookConfiguration                                                      |
      | resource_name | machine-api                                                                       |
      | p             | [{"op": "replace", "path": "/webhooks/0/clientConfig/service/port", "value":444}] |
      | type          | json                                                                              |
    And the step should succeed

    Given I use the "openshift-cluster-version" project
    Then I run the :scale admin command with:
      | resource | deployment               |
      | name     | cluster-version-operator |
      | replicas | 1                        |
    And the step should succeed

    Given I use the "openshift-machine-api" project
    Then I run the :scale admin command with:
      | resource | deployment           |
      | name     | machine-api-operator |
      | replicas | 1                    |
    And the step should succeed

    Given I wait up to 180 seconds for the steps to pass:
    """
    And I run the :get admin command with:
      | resource      | MutatingWebhookConfiguration |
      | resource_name | machine-api                  |
      | o             | json                         |
    Then the expression should be true>  @result[:parsed]['webhooks'][0]['clientConfig']['service']['port'] == 443
    """

  # @author miyadav@redhat.com
  # @case_id OCP-37744
  @admin
  Scenario Outline: kube-rbac-proxy should not expose tokens, have excessive verbosity
    Given I switch to cluster admin pseudo user
    Then I use the "<project>" project

    Given a pod becomes ready with labels:
      | api=clusterapi | <labels>  |
    When I run the :logs admin command with:
      | resource_name | <%= pod.name %>  |
      | c             | <container_name> |
    Then the output should not contain:
      | Response Headers |

   Examples:
      | container_name                  | project                            | labels                              |
      | kube-rbac-proxy-machine-mtrc    | openshift-machine-api              | k8s-app=controller                  |
      | kube-rbac-proxy-machineset-mtrc | openshift-machine-api              | k8s-app=controller                  |
      | kube-rbac-proxy-mhc-mtrc        | openshift-machine-api              | k8s-app=controller                  |
      | kube-rbac-proxy                 | openshift-cluster-machine-approver | app=machine-approver                |
      | kube-rbac-proxy                 | openshift-machine-api              | k8s-app=machine-api-operator        |
      | kube-rbac-proxy                 | openshift-machine-api              | k8s-app=cluster-autoscaler-operator |

