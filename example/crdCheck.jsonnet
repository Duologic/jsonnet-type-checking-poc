local validate = import '../main.libsonnet';

local crds = std.parseYaml(importstr './crds.yaml');
local object = {
  kind: 'ContactPoint',
  apiVersion: 'alerting.grafana.crossplane.io/v1alpha1',
  spec: {
    deletionPolicy: null,
    forProvider: {},
  },
};

assert validate.crdCheck(object, crds); true

