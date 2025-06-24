# Texura

AI game texture generation platform

## Project Structure 

```
.
├── apps/
│   ├── texture_engine/       # Core AI engine for texture generation using Stable Diffusion
│   └── texura_api/           # Go/Go-Chi based service layer exposing texture engine functionality via api
│
├── frontend/                 # Web frontend for users to interact with the texture platform
│
├── infra/
│   └── terraform/
│       └── env/
│           ├── development/  # Infrastructure as code (IaC) for the development environment
│           └── production/   # IaC for production deployment
```

## Dependencies and Tools

### Platform
- Kubernetes
- TerraForm
- Docker

### Backend Services
- GO
- Python
- Stable Diffusion

### Frontend
- React
- TanStack Query

## Local Development 

### Quickstart
```
docker compose up 
```

### Local KinD Cluster 

```
terraform init
```

```
terraform apply
```

