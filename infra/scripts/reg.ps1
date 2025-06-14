# PowerShell version of local registry setup for kind

$regName = "kind-registry"
$regPort = 5000

# 1. Create registry container unless it already exists
$regRunning = docker inspect -f '{{.State.Running}}' $regName 2>$null
if ($regRunning -ne "true") {
    docker run `
        -d --restart=always `
        -p "$regPort:$regPort" `
        --network bridge `
        --name $regName `
        registry:2
}

# # 2. Create kind cluster with containerd registry config dir enabled
# # $kindConfig = @"
# # kind: Cluster
# # apiVersion: kind.x-k8s.io/v1alpha4
# # containerdConfigPatches:
# # - |-
# #   [plugins."io.containerd.grpc.v1.cri".registry]
# #     config_path = "/etc/containerd/certs.d"
# # "@

# # $kindConfig | kind create cluster --config=-

# # 3. Add the registry config to the nodes
# Write hosts.toml to a temporary file
$tempPath = [System.IO.Path]::GetTempFileName()
$hostsToml = @"
[host."http://$regName:5000"]
"@
Set-Content -Path $tempPath -Value $hostsToml -Encoding UTF8

foreach ($node in $nodes) {
    docker exec $node mkdir -p $registryDir | Out-Null
    docker cp $tempPath "${node}:$registryDir/hosts.toml"
}

# Cleanup
Remove-Item $tempPath
# # # 4. Connect the registry to the kind network if not already connected
# # $connected = docker inspect -f='{{json .NetworkSettings.Networks.kind}}' $regName 2>$null
# # if ($connected -eq "null") {
# #     docker network connect "kind" $regName
# # }

# # # 5. Document the local registry
# # $registryConfigMap = @"
# # apiVersion: v1
# # kind: ConfigMap
# # metadata:
# #   name: local-registry-hosting
# #   namespace: kube-public
# # data:
# #   localRegistryHosting.v1: |
# #     host: "localhost:$regPort"
# #     help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
# # "@

# # $registryConfigMap | kubectl apply -f -