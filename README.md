# CloudShop — AWS 3-Tier Application with Application Load Balancers

This repository is a complete educational 3-tier web application:

```
Internet
   |
Route 53
   |
Public Frontend ALB
   |
Frontend EC2 (Nginx + React)
   |
Internal Backend ALB
   |
Backend EC2 (Java + Spring Boot)
   |
Amazon RDS PostgreSQL
```

## Project folders

- `frontend/` — React/Vite application.
- `backend/` — Java 21 / Spring Boot REST API.
- `infra/user-data/` — EC2 Launch Template bootstrap scripts.
- `infra/nginx/` — Nginx reverse-proxy configuration.
- `infra/diagrams/` — architecture notes.
- `AWS-DEPLOYMENT.md` — complete AWS Console deployment guide.

## Key design

The public frontend ALB is the public application entry point. The backend ALB is internal. Nginx serves the React application and proxies browser requests from `/api/` to the internal backend ALB. Spring Boot reads/writes PostgreSQL on RDS.

This avoids exposing the backend EC2 instances and avoids requiring a public backend URL in browser JavaScript.

## Local backend

Set:

```bash
export DB_URL=jdbc:postgresql://localhost:5432/cloudshop
export DB_USERNAME=postgres
export DB_PASSWORD=postgres
```

Then:

```bash
cd backend
mvn spring-boot:run
```

Health:

```
GET /api/health
```

Products:

```
GET /api/products
POST /api/products
DELETE /api/products/{id}
```

## Local frontend

```bash
cd frontend
npm install
npm run dev
```

Vite proxies `/api` to `localhost:8080`.

## AWS

Follow **AWS-DEPLOYMENT.md** from top to bottom. The required order is:

RDS → backend target group → internal backend ALB → backend Launch Template/EC2 → frontend target group → frontend Launch Template/EC2 → public frontend ALB → ACM → HTTPS → Route 53 → optional Auto Scaling Groups.

## Security

Do not commit real passwords. For a production deployment use AWS Secrets Manager or SSM Parameter Store, IAM roles, private subnets, HTTPS, CloudWatch, backups and Multi-AZ where required.

Repository:
https://github.com/shivraj-kadam/cursor
