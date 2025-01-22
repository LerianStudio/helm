# midaz-helm

## Use this Helm Chart in k8s Cluster

### Usage:
1. Ensure Helm is installed on your system. If not, follow the instructions at [Helm Installation Guide](https://helm.sh/docs/intro/install/).
2. Select k8s context.
3. Go to the chart path:
    ```sh
    cd charts/midaz
    ```
4. Install the Helm Dependencies:
    ```sh
    helm dependency update
    ```
5. Install the Helm chart using the following command:
    ```sh
    helm install <release_name> . --namespace <namespace> --values <values_file>
    ```

### Parameters:
- `<release_name>`: The name you want to give to the Helm release.
- `<namespace>`: The Kubernetes namespace where you want to install the chart.
- `<values_file>`: The path to a YAML file containing custom values for the chart.