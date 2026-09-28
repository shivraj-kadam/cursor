# AWS 3-Tier Student Management Application

React + Nginx frontend, Spring Boot backend, and Amazon RDS MySQL, deployed with EC2 Auto Scaling Groups and two Application Load Balancers.

## Architecture

~~~text
Internet
  |
Route 53
  |
ACM HTTPS
  |
Public Frontend ALB
  |
Frontend EC2 ASG (Nginx + React)
  |
/api proxy
  |
Internal Backend ALB
  |
Backend EC2 ASG (Java 17 + Spring Boot)
  |
MySQL 3306
  |
Amazon RDS
~~~

The public entry point is the frontend ALB. The backend ALB is internal. RDS is private.

## Repository

https://github.com/shivraj-kadam/cursor

## Source tree

~~~text
backend/
  pom.xml
  src/main/java/com/example/studentapp/
  src/main/resources/application.properties

frontend/
  package.json
  vite.config.js
  index.html
  src/

deploy/
  backend-user-data.sh
  frontend-user-data.sh
  backend-nginx-optional.conf
  frontend-nginx-note.txt
~~~

# Deployment order

Build from the back of the diagram toward the front:

1. VPC and six subnets
2. Internet Gateway and NAT Gateway
3. Security groups
4. Amazon RDS
5. Backend Launch Template
6. Backend Target Group
7. Internal Backend ALB
8. Backend Auto Scaling Group
9. Frontend Launch Template
10. Frontend Target Group
11. Public Frontend ALB
12. ACM certificate
13. Route 53
14. HTTPS listener
15. End-to-end testing

# 1. VPC

AWS Console → VPC → Create VPC.

Use:

~~~text
VPC: studentapp-vpc
CIDR: 10.0.0.0/16

Public:
public-subnet-a  10.0.1.0/24
public-subnet-b  10.0.2.0/24

Private application:
private-app-a  10.0.11.0/24
private-app-b  10.0.12.0/24

Private database:
private-db-a  10.0.21.0/24
private-db-b  10.0.22.0/24
~~~

Use two Availability Zones.

Attach an Internet Gateway named studentapp-igw.

Public route:

~~~text
0.0.0.0/0 → Internet Gateway
~~~

Create a NAT Gateway in a public subnet. Private application subnets use:

~~~text
0.0.0.0/0 → NAT Gateway
~~~

The NAT Gateway lets private EC2 instances run apt/npm/git during User Data.

# 2. Security groups

Create:

~~~text
studentapp-frontend-alb-sg
studentapp-frontend-ec2-sg
studentapp-backend-alb-sg
studentapp-backend-ec2-sg
studentapp-rds-sg
~~~

Rules:

| Security group | Port | Source |
|---|---:|---|
| Frontend ALB | 80 | Internet |
| Frontend ALB | 443 | Internet |
| Frontend EC2 | 80 | Frontend ALB SG |
| Backend ALB | 8080 | Frontend EC2 SG |
| Backend EC2 | 8080 | Backend ALB SG |
| RDS | 3306 | Backend EC2 SG |

Do not allow RDS 3306 from 0.0.0.0/0.

# 3. RDS

AWS Console → RDS → Databases → Create database.

Recommended:

~~~text
Engine: MySQL
DB identifier: studentapp-db
Database name: studentdb
Username: studentadmin
Port: 3306
Public access: No
VPC: studentapp-vpc
DB subnet group: private-db-a + private-db-b
Security group: studentapp-rds-sg
~~~

Wait for Status = Available.

Copy the RDS endpoint, for example:

~~~text
studentapp-db.xxxxx.ap-south-1.rds.amazonaws.com
~~~

The backend connection URL is:

~~~text
jdbc:mysql://RDS_ENDPOINT:3306/studentdb?useSSL=false&serverTimezone=UTC
~~~

# 4. Backend Launch Template

EC2 → Launch Templates → Create.

Name:

~~~text
studentapp-backend-template
~~~

Use Ubuntu Server 24.04 LTS and a suitable lab instance such as t3.micro.

Security group:

~~~text
studentapp-backend-ec2-sg
~~~

Paste deploy/backend-user-data.sh into User Data.

Before saving the template, replace:

~~~text
REPLACE_WITH_RDS_ENDPOINT
REPLACE_WITH_RDS_USERNAME
REPLACE_WITH_RDS_PASSWORD
~~~

The User Data installs Git, Java 17 and Maven, clones the repository, builds the Spring Boot JAR, creates a systemd service, and starts port 8080.

Important commands used by the bootstrap:

~~~bash
apt-get update -y
apt-get install -y git openjdk-17-jdk maven
git clone https://github.com/shivraj-kadam/cursor.git
mvn clean package -DskipTests
systemctl enable studentapp
systemctl restart studentapp
~~~

# 5. Backend Target Group

EC2 → Target Groups → Create.

~~~text
Name: studentapp-backend-tg
Target type: Instances
Protocol: HTTP
Port: 8080
Health path: /actuator/health
VPC: studentapp-vpc
~~~

# 6. Internal Backend ALB

EC2 → Load Balancers → Create → Application Load Balancer.

~~~text
Name: studentapp-backend-alb
Scheme: Internal
VPC: studentapp-vpc
Subnets: private-app-a + private-app-b
Security group: studentapp-backend-alb-sg
Listener: HTTP 8080
Forward: studentapp-backend-tg
~~~

Copy the internal ALB DNS name. It will be needed by Nginx on the frontend instances.

# 7. Backend Auto Scaling Group

EC2 → Auto Scaling Groups → Create.

~~~text
Name: studentapp-backend-asg
Launch template: studentapp-backend-template
Subnets: private-app-a + private-app-b
Desired: 2
Minimum: 2
Maximum: 4
Target group: studentapp-backend-tg
Health checks: EC2 + ELB
Grace period: 300 seconds
~~~

Test from inside the VPC:

~~~bash
curl http://BACKEND_ALB_DNS:8080/actuator/health
curl http://localhost:8080/actuator/health
curl http://localhost:8080/api/students
~~~

Expected initial students result:

~~~text
[]
~~~

Troubleshooting:

~~~bash
sudo systemctl status studentapp
sudo journalctl -u studentapp -n 100 --no-pager
sudo ss -lntp | grep 8080
~~~

# 8. Frontend Launch Template

EC2 → Launch Templates → Create.

Name:

~~~text
studentapp-frontend-template
~~~

Use Ubuntu Server 24.04 LTS.

Security group:

~~~text
studentapp-frontend-ec2-sg
~~~

Paste deploy/frontend-user-data.sh into User Data.

Replace:

~~~text
REPLACE_WITH_INTERNAL_BACKEND_ALB_DNS
~~~

with the internal backend ALB DNS name.

The frontend User Data installs Git, Nginx and npm, clones the repository, runs npm install and npm run build, copies the React build to Nginx, and configures:

~~~text
/api/* → Internal Backend ALB
/*     → React application
~~~

# 9. Frontend Target Group

Create:

~~~text
Name: studentapp-frontend-tg
Target type: Instances
Protocol: HTTP
Port: 80
Health path: /health
~~~

Nginx returns:

~~~text
frontend-ok
~~~

for /health.

# 10. Public Frontend ALB

Create an Application Load Balancer:

~~~text
Name: studentapp-frontend-alb
Scheme: Internet-facing
VPC: studentapp-vpc
Subnets: public-subnet-a + public-subnet-b
Security group: studentapp-frontend-alb-sg
Listener: HTTP 80
Forward: studentapp-frontend-tg
~~~

# 11. Frontend Auto Scaling Group

Create:

~~~text
Name: studentapp-frontend-asg
Launch template: studentapp-frontend-template
Subnets: private-app-a + private-app-b
Desired: 2
Minimum: 2
Maximum: 4
Target group: studentapp-frontend-tg
Health checks: EC2 + ELB
Grace period: 300 seconds
~~~

The frontend EC2 instances stay private. Only the frontend ALB is public.

# 12. Domain and HTTPS

AWS Certificate Manager → Request public certificate.

Request:

~~~text
student.example.com
~~~

Use DNS validation. Wait for Issued.

The certificate must be in the same AWS region as the frontend ALB.

On the frontend ALB add:

~~~text
HTTPS 443 → ACM certificate → studentapp-frontend-tg
~~~

Change HTTP 80 to:

~~~text
Redirect HTTP 80 → HTTPS 443
~~~

Route 53 → Hosted zone → Create A record:

~~~text
Name: student
Type: A
Alias: Yes
Target: studentapp-frontend-alb
~~~

Final URL:

~~~text
https://student.example.com
~~~

# 13. Request flow

~~~text
Browser
  ↓ HTTPS
Route 53
  ↓
Public Frontend ALB
  ↓ HTTP 80
Frontend EC2 / Nginx
  ↓ /api/*
Internal Backend ALB
  ↓ HTTP 8080
Backend EC2 / Spring Boot
  ↓ MySQL 3306
Amazon RDS
~~~

The browser never connects directly to the backend ALB or RDS.

# 14. Health checks

Frontend:

~~~text
GET /health
→ frontend-ok
~~~

Backend:

~~~text
GET /actuator/health
→ {"status":"UP"}
~~~

# 15. Final validation checklist

RDS:
- [ ] Available
- [ ] Private
- [ ] Database is studentdb
- [ ] Port 3306 allowed only from backend EC2 SG

Backend:
- [ ] Two healthy ASG instances
- [ ] Target group healthy
- [ ] Backend ALB is Internal
- [ ] Spring Boot listens on 8080
- [ ] /actuator/health returns UP
- [ ] /api/students returns JSON

Frontend:
- [ ] Two healthy ASG instances
- [ ] Target group healthy
- [ ] Nginx running
- [ ] /health returns frontend-ok
- [ ] React page loads

HTTPS:
- [ ] ACM certificate is Issued
- [ ] 443 listener exists
- [ ] 80 redirects to 443
- [ ] Route 53 alias points to frontend ALB
- [ ] Domain opens with HTTPS

# 16. Security and production notes

For this learning project, the database password is demonstrated in the backend Launch Template User Data. Do not use that approach for production secrets.

Production should use AWS Secrets Manager or Parameter Store with an EC2 IAM role.

Never commit:
- database passwords
- private keys
- .env files
- AWS access keys

For production database schema management, use Flyway/Liquibase instead of relying on Hibernate ddl-auto=update.

For production deployments, use CI/CD and an AMI or deployment mechanism rather than rebuilding application code only when a new EC2 instance launches.

# 17. Cost cleanup

Potentially billable resources include EC2, ALBs, NAT Gateway, RDS, Elastic IPs and Route 53 resources.

For a temporary lab, clean up after testing:

1. Route 53 records if no longer required
2. Load balancers
3. Auto Scaling Groups
4. EC2 instances
5. NAT Gateway
6. Elastic IP
7. RDS
8. DB subnet group
9. Security groups after dependencies are removed
10. Subnets
11. Route tables
12. Internet Gateway
13. VPC

Take an RDS snapshot first if the data is needed later.
