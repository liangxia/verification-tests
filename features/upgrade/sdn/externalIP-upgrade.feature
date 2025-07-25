Feature: SDN externalIP compoment upgrade testing

  # @author weliang@redhat.com
  @admin
  @upgrade-prepare
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy @disconnected @connected
  @hypershift-hosted
  @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9
  Scenario: OCP-44790:SDN Check the externalIP works well after upgrade - prepare
    Given I switch to cluster admin pseudo user
    And I run the :new_project client command with:
      | project_name | externalip-upgrade |
    Then the step should succeed
    Given I store the schedulable nodes in the :nodes clipboard
    And the Internal IP of node "<%= cb.nodes[0].name %>" is stored in the :hostip clipboard

    # Create additional network through CNO
    Given as admin I successfully merge patch resource "networks.config.openshift.io/cluster" with:
      | {"spec":{"externalIP":{"policy":{"allowedCIDRs":["<%= cb.hostip %>/24"]}}}} |

    # Create a svc with externalIP
    When I use the "externalip-upgrade" project
    Given I obtain test data file "networking/externalip_service1.json"
    And I wait up to 500 seconds for the steps to pass:
    """
    When I run oc create over "externalip_service1.json" replacing paths:
      | ["spec"]["externalIPs"][0] | <%= cb.hostip %>    |
      | n                          | externalip-upgrade  |
    Then the step should succeed
    """

    # Create a pod
    Given I obtain test data file "networking/externalip_pod_upgrade.yaml"
    When I run the :create client command with:
      | f | externalip_pod_upgrade.yaml |
      | n | externalip-upgrade          |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=externalip-pod    |
    And evaluation of `pod.name` is stored in the :pod1name clipboard

    # Curl externalIP:portnumber should pass
    And evaluation of `cb.hostip.include?(":") ? "[#{cb.hostip}]" : cb.hostip` is stored in the :hostip_url clipboard
    And I wait up to 60 seconds for the steps to pass:
    """
    When I execute on the "<%= cb.pod1name %>" pod:
      | /usr/bin/curl | --connect-timeout | 10 | <%= cb.hostip_url %>:27017 |
    Then the output should contain:
      | Hello OpenShift! |
    """

  # @author weliang@redhat.com
  # @case_id OCP-44790
  @admin
  @upgrade-check
  @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy @disconnected @connected
  @hypershift-hosted
  Scenario: OCP-44790:SDN Check the externalIP works well after upgrade
    Given I switch to cluster admin pseudo user
    # Get the external ip from  service
    When I use the "externalip-upgrade" project
    And evaluation of `service('service-unsecure').raw_resource.dig('spec','externalIPs')[0]` is stored in the :hostip clipboard
    Given a pod becomes ready with labels:
      | name=externalip-pod    |
    And evaluation of `pod.name` is stored in the :pod1name clipboard

    # Curl externalIP:portnumber should pass
    And evaluation of `cb.hostip.include?(":") ? "[#{cb.hostip}]" : cb.hostip` is stored in the :hostip_url clipboard
    When I execute on the "<%= cb.pod1name %>" pod:
      | /usr/bin/curl | --connect-timeout | 10 | <%= cb.hostip_url %>:27017 |
    Then the output should contain:
      | Hello OpenShift! |

    # Clean-up required to erase above externalIP policy after testing done
    Given I register clean-up steps:
    """
    Given as admin I successfully merge patch resource "networks.config.openshift.io/cluster" with:
      | {"spec":{"externalIP":{"policy":{"allowedCIDRs": null}}}} |
    """
    ### delete this project,make sure project is deleted
    Given the "externalip-upgrade" project is deleted
