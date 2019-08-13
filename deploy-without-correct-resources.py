from kubernetes import client, config, watch
from kubernetes.client.rest import ApiException
from kubernetes.client.api_client import ApiClient
import sys
import ast

config.load_kube_config()
api = client.CoreV1Api()
deploymentAPI = client.ExtensionsV1beta1Api()


def check_deployments():
  try:
    namespaces = api.list_namespace().items
    matches = []
    deployments_without_correct_resources = []
    for namespace in namespaces:
      deployments = deploymentAPI.list_namespaced_deployment(namespace.metadata.name).items
      for deploy in deployments:
        deployment = deploy.metadata.name
        containers = deploy.spec.template.spec.containers
        for cont in containers:
          r = cont.resources
          r = ast.literal_eval(str(r))
          if "requests" not in r:
            matches.append(deployment)
          elif "limits" not in r:
            matches.append(deployment)
          elif r.get("requests") == None:
            matches.append(deployment)
          elif r.get("limits") == None:
            matches.append(deployment)
          elif r.get("requests").get("cpu") == None:
            matches.append(deployment)
          elif r.get("requests").get("memory") == None:
            matches.append(deployment)
          elif r.get("limits").get("memory") == None:
            matches.append(deployment)
    for match in matches:
      if match not in deployments_without_correct_resources:
        deployments_without_correct_resources.append(match)
    for d in deployments_without_correct_resources:
      print(d)

  except ApiException as e:
    print("Exception when calling the function: %s\n" % e)


if __name__ == '__main__':
  check_deployments()
