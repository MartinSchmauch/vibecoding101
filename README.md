This is a blueprint for creating and deploying a webapp in less than one hour. The webserver is based on flask, the frontend is simple html and CSS

# Übersicht der Schritte
- Lokale Entwicklung (Mac)
- Docker & Testing
- GCP Setup via CLI
- Terraform Infrastructure
- GitHub Actions CI/CD
- Domain & SSL (optional)
- Production Deployment

# Voraussetzungen
- Python 3.11+
- Docker Desktop installiert & laufend
- Google Cloud Account (Kreditkarte für Billing!)
- GitHub Account
- Domain (optional, für SSL)

# 1. Environment Setup

## Git initialisieren
```bash
git init
```

## Python Virtual Environment erstellen
```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

## Environment Variables konfigurieren
```bash
# .env Datei erstellen
cp .env.example .env
```

**Öffne `.env` und ändere:**
```bash
SECRET_KEY=<generiere mit: openssl rand -hex 32>
PORT=5000
```

## Optional: Schnellstart mit Makefile
```bash
make setup       # Einmalig: venv + .env erstellen
make dev         # Entwicklung starten
make docker-run  # Docker testen
```

# 2. App lokal testen
## App starten
```bash
python app.py
```

## In anderem Terminal testen
```bash
curl http://localhost:5000
curl http://localhost:5000/api/health
```

## Im Browser öffnen
```bash
open http://localhost:5000
```

# 3. Docker lokal testen
**Docker muss bereits installiert sein und laufen!**

## Build
```bash
docker build -t meine-app:latest .
```

## Run (Port 8080 lokal)
```bash
docker run -p 8080:8080 \
  -e PORT=8080 \
  -e SECRET_KEY=test-key \
  meine-app:latest
```

## Test
```bash
curl http://localhost:8080/api/health
open http://localhost:8080
```

## Stoppen
```bash
docker ps  # Finde Container ID
docker stop <CONTAINER_ID>
```

# 4. GCP Setup via CLI

## Google Cloud SDK installieren (macOS via Homebrew)
```bash
brew install google-cloud-sdk
```

## Login
```bash
gcloud auth login
```

## Projekt erstellen
```bash
gcloud projects create meine-app-12345 --name="Meine App"
```
**⚠️ WICHTIG:** Ersetze `meine-app-12345` durch deine eindeutige Project ID!

## Projekt setzen
```bash
gcloud config set project meine-app-12345
```

## Billing aktivieren
Gehe zu: [console.cloud.google.com/billing](https://console.cloud.google.com/billing)  
**WICHTIG: Ohne Billing geht nichts!**

## APIs aktivieren
```bash
gcloud services enable compute.googleapis.com
gcloud services enable artifactregistry.googleapis.com
```

## Kostenalarm setzen
```bash
gcloud billing budgets create --billing-account=BILLING_ID \
  --display-name="Meine App Budget" \
  --budget-amount=10USD \
  --threshold-rule=percent=50 \
  --threshold-rule=percent=90
```
**Tipp:** Finde deine `BILLING_ID` mit: `gcloud billing accounts list`

# 5. Service Account für CI/CD

## Service Account erstellen
```bash
gcloud iam service-accounts create github-actions \
  --display-name="GitHub Actions Deployer"
```

## Permissions geben
```bash
gcloud projects add-iam-policy-binding meine-app-12345 \
  --member="serviceAccount:github-actions@meine-app-12345.iam.gserviceaccount.com" \
  --role="roles/compute.instanceAdmin.v1"

gcloud projects add-iam-policy-binding meine-app-12345 \
  --member="serviceAccount:github-actions@meine-app-12345.iam.gserviceaccount.com" \
  --role="roles/artifactregistry.writer"

gcloud projects add-iam-policy-binding meine-app-12345 \
  --member="serviceAccount:github-actions@meine-app-12345.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountUser"
```

## JSON Key erstellen (für GitHub Secrets)
```bash
gcloud iam service-accounts keys create gcp-key.json \
  --iam-account=github-actions@meine-app-12345.iam.gserviceaccount.com
```

**⚠️ WICHTIG:** `gcp-key.json` NIEMALS committen! Ist bereits in `.gitignore`

```bash
cat gcp-key.json  # Kopiere Inhalt für GitHub Secret
```

# 6. Artifact Registry

## Docker Registry für Images erstellen
```bash
gcloud artifacts repositories create meine-app \
  --repository-format=docker \
  --location=europe-west1 \
  --description="Docker images für meine-app"
```

## Docker Auth konfigurieren
```bash
gcloud auth configure-docker europe-west1-docker.pkg.dev
```

# 7. Terraform

## Terraform installieren (macOS via Homebrew)
```bash
brew install terraform
```

## Terraform Variablen konfigurieren
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

**Öffne `terraform.tfvars` und ändere:**
```terraform
project_id = "meine-app-12345"  # Deine GCP Project ID!
region     = "europe-west1"
zone       = "europe-west1-b"
```

## Init
```bash
terraform init
```

## Plan (zeigt was erstellt wird)
```bash
terraform plan
```

## Apply (ERSTELLT RESOURCEN - KOSTET GELD!)
```bash
terraform apply
```
Tippe: `yes`

## IP-Adresse notieren
```bash
terraform output instance_ip
```
z.B. 34.22.45.67

# 8. GitHub Actions CI/CD

## GitHub Repository erstellen
```bash
# Zurück ins Projekt-Root
cd ..

# GitHub Repo erstellen (via CLI oder Website)
gh repo create meine-app --public --source=. --remote=origin
```
→ Oder manuell auf github.com

## GitHub Secrets konfigurieren
Gehe zu: `https://github.com/DEIN-USERNAME/meine-app/settings/secrets/actions`

**Erstelle folgende "Repository Secrets":**
- `GCP_PROJECT_ID` = `meine-app-12345`
- `GCP_SA_KEY` = Inhalt von `gcp-key.json` (kompletter JSON)
- `SECRET_KEY` = Generiere mit: `openssl rand -hex 32`

## First Deployment
```bash
# Code committen
git add .
git commit -m "Initial commit"
git push origin main
```

**GitHub Actions läuft automatisch!**  
Prüfe: `https://github.com/DEIN-USERNAME/meine-app/actions`

⚠️ **WICHTIG:** GitHub Actions Ordner muss `.github/workflows/` heißen (mit 's')!

# 9. Domain & SSL (optional)

## Domain kaufen
Kaufe Domain bei Namecheap, Google Domains, etc.  
Z.B. `meine-app.de`

## DNS konfigurieren
```bash
# Hole VM IP
cd terraform
terraform output instance_ip
# z.B. 34.22.45.67
```

**Bei deinem Domain-Provider:**
```
Type: A
Host: @ (oder www)
Value: 34.22.45.67 (deine instance_ip)
TTL: 300
```

## Go-Live
```bash
# VM neustarten (Caddy holt SSL-Zertifikat)
gcloud compute instances stop meine-app-vm --zone=europe-west1-b
gcloud compute instances start meine-app-vm --zone=europe-west1-b
```

**Warte 5-10 Minuten**, dann öffne: `https://meine-app.de`

# 10. Production & Updates

## Health Checks
```bash
# Logs prüfen
gcloud compute ssh meine-app-vm --zone=europe-west1-b
docker ps
docker logs <CONTAINER_ID> --tail 100
```

## Updates deployen
```bash
git add .
git commit -m "Feature X"
git push origin main
```
→ GitHub Actions deployed automatisch!

## Kosten überwachen
Prüfe regelmäßig: [console.cloud.google.com/billing](https://console.cloud.google.com/billing)

# Kosten-Übersicht (e2-micro Free Tier)
- **VM:** ~$0 (Free Tier: 1x e2-micro in us-regions)
- **Static IP:** ~$3/Monat (wenn VM läuft: $0)
- **Artifact Registry:** ~$0.10/GB/Monat
- **Traffic:** 1GB/Monat free, dann ~$0.12/GB
- **Total:** ~$0-5/Monat für kleine App

# Quick Commands - Cheat Sheet

## Lokale Entwicklung
```bash
python app.py                    # Dev server
docker build -t app . && docker run -p 8080:8080 --env-file .env app  # Docker test
```

## Terraform
```bash
cd terraform
terraform plan                   # Zeige Änderungen
terraform apply                  # Apply Änderungen
terraform destroy                # Lösche ALLES
```

## GCP
```bash
gcloud compute ssh meine-app-vm --zone=europe-west1-b  # SSH
gcloud compute instances list    # Zeige VMs
gcloud compute instances stop meine-app-vm --zone=europe-west1-b  # Stop VM
gcloud compute instances start meine-app-vm --zone=europe-west1-b  # Start VM
```

## GitHub
```bash
git add . && git commit -m "msg" && git push  # Deploy triggern
```

## Debugging
```bash
curl http://IP:8080/api/health   # Health Check
docker logs <CONTAINER_ID>        # App Logs
gcloud compute instances get-serial-port-output meine-app-vm  # Boot Logs
```

