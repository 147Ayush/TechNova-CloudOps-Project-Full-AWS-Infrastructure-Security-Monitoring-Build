**TechNova CloudOps Project – Full AWS Infrastructure, Security & Monitoring Build**
=================================================

A real-world style **Cloud Infrastructure + Security + Monitoring + Troubleshooting** project built fully on **AWS using Terraform**.This project replicates the environment and tasks performed by Cloud Support / DevOps / CIS teams in real client setups.

**📌 Project Overview**
-----------------------

TechNova Solutions is migrating part of their Healthcare Platform to AWS.Your goal is to build a **complete 2-tier architecture**, secure it, monitor it, troubleshoot failures, and test backups — exactly like a real cloud team onboarding a new application.

This project includes:

- ✔ 2-Tier Infra (Web + DB)
- ✔ IAM Security
- ✔ Network Security
- ✔ CloudWatch Monitoring + Logs
- ✔ CPU Alerting
- ✔ Failure Simulation & Troubleshooting
- ✔ Backup + Rollback
- ✔ Automation using Terraform

**🏗 Architecture Overview**
----------------------------

### **Tier 1 – Web Server (EC2)**

*   Amazon Linux 2 EC2
    
*   Apache Web Server
    
*   Custom message:**“TechNova Web Tier Active”**
    
*   CloudWatch Agent installed
    
*   Apache logs sent to CloudWatch Logs
    
*   CPU / Memory / Disk / Network monitored
    

### **Tier 2 – Database (RDS MySQL)**

*   AWS RDS MySQL 8
    
*   Private subnet, no external access
    
*   Tables: **Patients**, **Diagnostics**
    
*   Sample rows inserted manually after deployment
    
*   DB accessible only from Web SG
    

**🔐 Security Features**
------------------------

### **IAM Hardening**

A restricted IAM user **support-user** with:

*   Start/Stop/Reboot EC2 (web instance only)
    
*   View CloudWatch logs/metrics
    
*   Read-only RDS descriptions
    

### **Network Hardening**

*   Web SG:
    
    *   Allow HTTP (80) from anywhere
        
    *   Optional SSH (restricted)
        
*   DB SG:
    
    *   Allow MySQL (3306) only from Web SG
        
    *   Block all outside traffic
        
*   Private subnet for DB
    
*   Public subnet for Web
    

**📉 Monitoring & Alerting**
----------------------------

### **CloudWatch Metrics**

*   CPU Utilization
    
*   Memory Usage
    
*   Disk Usage
    
*   Network Traffic
    

(Enhanced via CloudWatch Agent)

### **CloudWatch Logs**

*   Apache access logs
    
*   Apache error logs
    

Log group:
```bash
/TechNova-CloudOps-Project-Full-AWS-Infrastructure-Security-Monitoring-Build/web-logs
```
### **Alert**

*   Alarm when **CPU > 70%**
    
*   Sends notification to SNS topic technova-cloud-alerts
    

**🧪 Troubleshooting Scenario**
-------------------------------

You must simulate and fix a real production-like failure:

### **Break the system**

1.  Stop the RDS MySQL instance
    
2.  Visit the web server
    
3.  App should show **DB connection error**
    

### **Fix**

1.  Start RDS again
    
2.  Refresh web page
    
3.  App should work normally
    

**💾 Backup / Rollback**
------------------------

Terraform automatically creates:

### **1\. EBS Snapshot**

For the Web Server root volume

### **2\. RDS Snapshot**

For the MySQL database

You can restore either snapshot manually via AWS Console to confirm rollback.

**📁 Project Structure**
------------------------
```bash
TechNova-CloudOps-Project-Full-AWS-Infrastructure-Security-Monitoring-Build
    │── main.tf
    │── providers.tf
    │── variables.tf
    │── web_userdata.tpl
    │── README.md
```

**🚀 Deployment Instructions**
------------------------------

### **1\. Clone the repo**

```bash
git clone https://github.com/147Ayush/TechNova-CloudOps-Project-Full-AWS-Infrastructure-Security-Monitoring-Build.git
cd technova-cloud   
```

### **2\. Initialize Terraform**

```bash
 terraform init   
```

### **3\. Review or update variables**

Edit variables.tfEspecially:

*   aws\_region
    
*   db\_password
    
*   allowed\_ssh\_cidr
    

### **4\. Apply the infrastructure**
```bash
terraform apply
```
Confirm with **yes**.

### **5\. Outputs**

After apply, Terraform prints:

*   Web Server Public IP
    
*   RDS Endpoint
    
*   IAM Support User Access Keys
    
You should see:
```bash
echNova-CloudOps-Project-Full-AWS-Infrastructure-Security-Monitoring-Build Tier Active
```

**🗂 How to Insert Sample DB Data**
-----------------------------------

SSH into web server or use local MySQL client:

```bash
CREATE TABLE Patients (    id INT AUTO_INCREMENT PRIMARY KEY,    name VARCHAR(100),    age INT  );
CREATE TABLE Diagnostics (    id INT AUTO_INCREMENT PRIMARY KEY,    patient_id INT,    report VARCHAR(255)  );

INSERT INTO Patients(name, age) VALUES
('John Doe', 45),
('Lisa Ray', 29),
('Sam Patel', 34);

INSERT INTO Diagnostics(patient_id, report) VALUES
(1, 'Blood Report: Normal'),
(2, 'X-ray: Clear'),
(3, 'MRI: No issue');
```  

**⚠️ Cleanup**
--------------

Stop billing when done:
```bash
terraform destroy 
```
