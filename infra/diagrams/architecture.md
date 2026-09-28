# AWS architecture

## Three tiers

### Tier 1 — Frontend
Route 53 → public Application Load Balancer → frontend EC2 Launch Template → Nginx → React/Vite.

### Tier 2 — Backend
Frontend Nginx /api proxy → internal Application Load Balancer → backend EC2 Launch Template → Java 21 / Maven / Spring Boot REST API.

### Tier 3 — Database
Spring Boot → PostgreSQL on Amazon RDS.

## Security boundaries

- Public internet reaches only the frontend ALB.
- Frontend EC2 accepts HTTP only from the frontend ALB security group.
- Backend ALB accepts HTTP only from the frontend EC2 security group.
- Backend EC2 accepts port 8080 only from the backend ALB security group.
- RDS accepts port 5432 only from the backend EC2 security group.
- SSH should be restricted to the administrator IP or replaced by Systems Manager.

## Request flow

Domain → Route 53 → Frontend ALB → Frontend EC2/Nginx → Backend ALB → Backend EC2/Spring Boot → RDS PostgreSQL.