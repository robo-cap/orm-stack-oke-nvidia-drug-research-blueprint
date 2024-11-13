controller:
  service:
    targetPorts:
      http: http
      https: https
    annotations:
      oci.oraclecloud.com/load-balancer-type: "lb"
      service.beta.kubernetes.io/oci-load-balancer-shape: "flexible"
      service.beta.kubernetes.io/oci-load-balancer-shape-flex-min: "${min_bw}"
      service.beta.kubernetes.io/oci-load-balancer-shape-flex-max: "${max_bw}"
      service.beta.kubernetes.io/oci-load-balancer-security-list-management-mode: "%{ if create_cluster }None%{ else }All%{ endif }"
      oci.oraclecloud.com/initial-freeform-tags-override: '{"state_id": "${state_id}", "application": "nginx", "role": "service_lb"}'
      %{ if create_cluster ~}oci.oraclecloud.com/oci-network-security-groups: "${pub_lb_nsg_id}"%{ endif ~}