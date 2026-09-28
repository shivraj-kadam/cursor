# CloudShop AWS 3-Tier Deployment Runbook

Repository: https://github.com/shivraj-kadam/cursor

## 1. Final architecture

Internet
→ Route 53
→ Public Frontend ALB
→ Frontend EC2 instances (Nginx + React)
→ Internal Backend ALB
→ Backend EC2 instances (Java + Spring Boot)
→ RDS PostgreSQL

The database is the third tier. The backend is the second tier. The frontend is the first tier.

## 2. AWS Region and VPC

Use one AWS Region for all resources. The examples below assume a VPC with at least two Availability Zones.

Recommended learning layout:

- 2 public subnets: frontend ALB
- 2 private application subnets: frontend/backend EC2
- 2 private database subnets: RDS
- Internet Gateway for public subnets
- NAT Gateway if private EC2 instances need internet access to install packages/clone GitHub

For a production design, use VPC endpoints where appropriate and minimize NAT traffic.

## 3. Security groups

Create these security groups in EC2 → Security Groups.

### sg-frontend-alb

Inbound:
- HTTP 80 from 0.0.0.0/0
- HTTPS 443 from 0.0.0.0/0

Outbound:
- All traffic

### sg-frontend-ec2

Inbound:
- HTTP 80, source = sg-frontend-alb

Optional administration:
- SSH 22, source = My IP only

Outbound:
- All traffic

### sg-backend-alb

Inbound:
- HTTP 80, source = sg-frontend-ec2

Outbound:
- All traffic

### sg-backend-ec2

Inbound:
- TCP 8080, source = sg-backend-alb

Optional administration:
- SSH 22, source = My IP only

Outbound:
- All traffic

### sg-rds

Inbound:
- PostgreSQL TCP 5432, source = sg-backend-ec2

Outbound:
- Default

Do not use 0.0.0.0/0 for database port 5432.

## 4. Create the RDS subnet group first

Open RDS → Subnet groups → Create DB subnet group.

Set:
- Name: cloudshop-db-subnet-group
- VPC: your application VPC
- Add the two private database subnets

RDS requires DB subnets in multiple Availability Zones.

## 5. Create PostgreSQL RDS

Open RDS → Databases → Create database.

Choose:
- Standard create
- Engine: PostgreSQL
- Version: a currently supported PostgreSQL version
- Template: Dev/Test for the lab
- DB identifier: cloudshop-db
- Master username: cloudshop_admin
- Set a strong password and keep it private
- Instance class: choose a low-cost class suitable for your account
- Storage: General Purpose SSD
- Initial database name: cloudshop
- VPC: your application VPC
- DB subnet group: cloudshop-db-subnet-group
- Public access: No
- VPC security group: choose existing sg-rds
- Port: 5432
- Encryption: enabled
- Automated backups: enabled

Create the database.

Wait until the RDS status becomes Available.

Copy the RDS endpoint. It looks similar to:

cloudshop-db.xxxxxx.ap-south-1.rds.amazonaws.com

Do not add http:// to the endpoint.

## 6. Database connection string

The backend will use:

jdbc:postgresql://RDS_ENDPOINT:5432/cloudshop

Example:

jdbc:postgresql://cloudshop-db.xxxxxx.ap-south-1.rds.amazonaws.com:5432/cloudshop

Do not commit the real password.

## 7. Backend target group

Open EC2 → Target Groups → Create target group.

Choose:
- Target type: Instances
- Name: cloudshop-backend-tg
- Protocol: HTTP
- Port: 8080
- VPC: application VPC

Health checks:
- Protocol: HTTP
- Path: /api/health
- Port: traffic port
- Success codes: 200

Do not register instances yet if you plan to launch them through a Launch Template/Auto Scaling Group.

## 8. Backend internal ALB

Open EC2 → Load Balancers → Create Load Balancer → Application Load Balancer.

Set:
- Name: cloudshop-backend-alb
- Scheme: Internal
- IP address type: IPv4
- VPC: application VPC
- Mappings: two private application subnets
- Security group: sg-backend-alb
- Listener: HTTP 80
- Default action: forward to cloudshop-backend-tg

Create the ALB.

Copy its DNS name, for example:

internal-cloudshop-backend-alb-123456.ap-south-1.elb.amazonaws.com

This DNS name is used only inside the VPC.

## 9. Backend Launch Template

Open EC2 → Launch Templates → Create launch template.

Name:
cloudshop-backend-lt

AMI:
Ubuntu Server 24.04 LTS or another current supported Ubuntu LTS.

Instance type:
Use a small suitable instance for the lab.

Key pair:
Choose one if you need SSH. Systems Manager is preferable where available.

Network:
Do not hard-code a public IP requirement. Launch into a private application subnet when using the recommended architecture.

Security group:
sg-backend-ec2

IAM instance profile:
Use an instance role if you use Systems Manager or Secrets Manager.

Advanced details → User data:
Copy infra/user-data/backend-user-data.sh from this repository.

Before launching, replace:

REPLACE_RDS_ENDPOINT
REPLACE_DB_USERNAME
REPLACE_DB_PASSWORD

with your real values.

Important:
For a real environment, do not put the database password directly in User Data. Store it in AWS Secrets Manager or SSM Parameter Store and let the instance role retrieve it.

The script installs:
- Git
- OpenJDK 21
- Maven

Then it clones the repository, builds the backend and starts Spring Boot with systemd.

## 10. Launch backend instance

Launch one backend instance from the template for the first test.

Choose a private application subnet.

After the instance starts, wait several minutes for User Data to finish.

Check target registration:
EC2 → Target Groups → cloudshop-backend-tg → Targets.

The target should become healthy.

If unhealthy, connect using Session Manager/SSH and run:

sudo systemctl status cloudshop-backend
sudo journalctl -u cloudshop-backend -n 100 --no-pager
curl http://127.0.0.1:8080/api/health

Expected local response:

{"status":"UP"}

Also check:

sudo cat /var/log/cloudshop-backend-bootstrap.log

## 11. Test backend ALB

From a frontend instance later, test:

curl http://INTERNAL_BACKEND_ALB_DNS/api/health

Expected:

{"status":"UP"}

Do not expect the internal ALB to be reachable directly from the public internet.

## 12. Frontend target group

Create another target group.

Name:
cloudshop-frontend-tg

Target type:
Instances

Protocol:
HTTP

Port:
80

Health check path:
 /health

Success code:
200

## 13. Frontend Launch Template

Open EC2 → Launch Templates → Create launch template.

Name:
cloudshop-frontend-lt

AMI:
Ubuntu Server 24.04 LTS.

Instance type:
Small suitable lab instance.

Security group:
sg-frontend-ec2

Subnet:
private application subnet is recommended.

User Data:
copy infra/user-data/frontend-user-data.sh.

Before launch, replace:

REPLACE_BACKEND_ALB_DNS

with the DNS name copied from the internal backend ALB.

The script installs:
- Git
- Node.js
- Nginx

It clones the repository, installs frontend dependencies, builds the Vite application, places the build in /var/www/cloudshop, configures Nginx and starts Nginx.

## 14. Launch frontend instance

Launch one frontend instance from cloudshop-frontend-lt.

Wait for User Data.

Check:

sudo systemctl status nginx
sudo nginx -t
curl http://127.0.0.1/health

Expected:

{"status":"UP"}

Check:

sudo cat /var/log/cloudshop-frontend-bootstrap.log

## 15. Frontend public ALB

Open EC2 → Load Balancers → Create Load Balancer → Application Load Balancer.

Set:
- Name: cloudshop-frontend-alb
- Scheme: Internet-facing
- IP address type: IPv4
- VPC: application VPC
- Mappings: two public subnets in different AZs
- Security group: sg-frontend-alb
- HTTP listener: port 80

For the initial HTTP test, forward port 80 to cloudshop-frontend-tg.

After HTTPS is configured, change port 80 to redirect to 443.

## 16. Verify frontend target health

Open:

EC2 → Target Groups → cloudshop-frontend-tg → Targets.

The frontend instance should become healthy.

If unhealthy:

curl http://127.0.0.1/health
sudo nginx -t
sudo systemctl status nginx
sudo tail -n 100 /var/log/nginx/error.log

## 17. First ALB test before DNS

Copy the frontend ALB DNS name.

Open:

http://FRONTEND_ALB_DNS

The React page should appear.

The product cards should load from:

Frontend ALB
→ Frontend EC2 Nginx
→ Internal Backend ALB
→ Backend EC2
→ RDS

This is the important end-to-end test.

## 18. ACM certificate

Open AWS Certificate Manager.

Request a public certificate for your real domain.

Example:

example.com
www.example.com

Choose DNS validation.

If the domain is hosted in Route 53, use the automatic DNS validation option where available.

Wait until certificate status is Issued.

The ACM certificate must be in the same AWS Region as the ALB.

## 19. HTTPS listener

Open:

EC2 → Load Balancers → cloudshop-frontend-alb → Listeners.

Add listener:
- HTTPS
- Port 443
- Default action: forward to cloudshop-frontend-tg
- Security group: sg-frontend-alb already permits 443
- Select the ACM certificate

Then edit HTTP port 80 listener:

Action:
Redirect to HTTPS
Port:
443
Protocol:
HTTPS
Status:
301

Now the public application uses HTTPS.

## 20. Route 53 domain

Open Route 53 → Hosted zones.

If the domain is managed by Route 53, create/use its hosted zone.

Create record:

Name:
www

Type:
A

Alias:
Yes

Route traffic to:
Application Load Balancer

Select:
cloudshop-frontend-alb

If you want the apex domain, create an A alias for the zone apex as well.

## 21. Final DNS test

Wait for DNS propagation.

Open:

https://www.yourdomain.com

Then test:

https://www.yourdomain.com/api/health

The second URL should be handled by Nginx and internally forwarded to the backend ALB.

Expected:

{"status":"UP"}

Then load the products page and verify that the three seed products appear.

## 22. Auto Scaling after the first successful test

Do not start with Auto Scaling until one backend and one frontend instance work.

Then create:

### Backend ASG
- Launch template: cloudshop-backend-lt
- Minimum: 2
- Desired: 2
- Maximum: 4
- Subnets: private application subnets
- Target group: cloudshop-backend-tg

### Frontend ASG
- Launch template: cloudshop-frontend-lt
- Minimum: 2
- Desired: 2
- Maximum: 4
- Subnets: private application subnets
- Target group: cloudshop-frontend-tg

The ALBs will distribute traffic across healthy instances.

## 23. Common failures

### Backend target unhealthy

Run:

sudo systemctl status cloudshop-backend
curl http://127.0.0.1:8080/api/health
sudo journalctl -u cloudshop-backend -n 100 --no-pager

If the application cannot connect to RDS, verify:
- DB endpoint
- DB name
- username/password
- sg-rds inbound 5432 source
- route/NACL configuration
- RDS status

### Frontend target unhealthy

Run:

sudo systemctl status nginx
sudo nginx -t
curl http://127.0.0.1/health

### API works locally but not through backend ALB

Verify:
- backend target group port = 8080
- backend EC2 SG allows 8080 from backend ALB SG
- backend ALB is internal
- health check = /api/health
- target is healthy

### Frontend works but products do not load

Verify:
- Nginx has the correct backend ALB DNS
- frontend EC2 can resolve the internal ALB
- frontend EC2 can reach backend ALB port 80
- backend target is healthy
- /api/products returns JSON from backend

Check:

sudo cat /etc/nginx/sites-available/cloudshop
sudo tail -n 100 /var/log/nginx/error.log

### Database connection error

Check:

RDS → Connectivity & security → endpoint, port, VPC and security group.

The RDS endpoint is not a URL. Use:

jdbc:postgresql://ENDPOINT:5432/cloudshop

## 24. Security rules to remember

Never:
- expose RDS to 0.0.0.0/0
- expose backend port 8080 to the internet
- commit database passwords
- put private ALB DNS names in public frontend JavaScript
- use a permanent 0.0.0.0/0 SSH rule

Prefer:
- security-group-to-security-group rules
- Secrets Manager/SSM for secrets
- Systems Manager Session Manager
- HTTPS
- encrypted RDS
- backups
- CloudWatch logs/alarms
- Auto Scaling
- Multi-AZ for production

## 25. Exact deployment order

1. VPC/subnets/routes
2. Security groups
3. RDS subnet group
4. RDS PostgreSQL
5. Backend target group
6. Internal backend ALB
7. Backend Launch Template
8. Backend EC2
9. Verify RDS + Spring Boot + backend ALB
10. Frontend target group
11. Frontend Launch Template
12. Frontend EC2
13. Public frontend ALB
14. Verify frontend ALB
15. ACM certificate
16. HTTPS listener
17. HTTP → HTTPS redirect
18. Route 53 alias
19. Full domain test
20. Auto Scaling Groups
21. CloudWatch monitoring

This order intentionally starts at the database and moves upward through backend and frontend, matching the three-tier dependency flow.
