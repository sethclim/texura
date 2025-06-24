# Texura

AI game texture generation platform

## Project Structure 

```
.
├── apps/
│   ├── texture_engine/       # Core AI engine for texture generation using Stable Diffusion
│   └── texura_api/           # Go/Go-Chi APIvservice layer exposing texture engine functionality
│
├── frontend/                 # Web frontend for users to interact with the texture platform
│
├── infra/
│   ├── scripts/              # Helper scripts for managing cluster
│   └── terraform/
│       └── environments/
│           ├── dev/          # Infrastructure as code (IaC) for the development environment
│           └── prod/         # IaC for production deployment
```

## Dependencies and Tools

### Platform
- [Kubernetes](https://kubernetes.io/)
- [TerraForm](https://developer.hashicorp.com/terraform/)
- [Docker](https://www.docker.com/)

### Backend Services
- [GO](https://go.dev/)
- [Python](https://www.python.org/)
- [Stable Diffusion](https://stability.ai/)
- [MinIO](https://min.io/) (local S3)

### Frontend
- [React](https://react.dev/)
- [TanStack Query](https://tanstack.com/query/latest)

## Local Development 

### Quickstart
```
docker compose up 
```

### Local KinD Cluster 
install docker [docs.docker.com/desktop/setup/install/linux/](https://docs.docker.com/desktop/setup/install/linux/)

```
docker --version
```

install terraform [developer.hashicorp.com/terraform/install](https://developer.hashicorp.com/terraform/install)
```
terraform --version
```

```
terraform init
```

```
terraform apply
```

