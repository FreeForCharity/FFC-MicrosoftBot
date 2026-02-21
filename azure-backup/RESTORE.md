# FFC ChatBot — Azure Restore Guide

**Backup Date:** February 20, 2026
**Subscription:** FFC - Microsoft Azure Sponsorship (`dea314c6-800f-4410-a095-415d4c83d681`)
**Tenant:** Free For Charity (`80c64bf2-fa5b-425c-9a5a-1fcf282d3274`)
**Resource Group:** `FFC-ChatBot` (East US)

---

## Why This Was Shut Down

The chatbot infrastructure was **not actively in use** but cost **~$134/month** (~$1,600/year). All resources were exported and archived here before deletion to free up Azure Sponsorship credits.

### Known Issues at Time of Shutdown

- **Container restart loop:** The container instance `ffc-influence-ai-bot` had accumulated **16,013 restarts**, indicating the container was continuously crashing and restarting. This should be investigated and resolved before redeploying.
- **EOL runtimes:** Node.js ~14 and PHP 5.6 were originally configured. Backup configs have been updated to Node.js ~20 (LTS) and PHP disabled.
- **TLS versions:** Updated from TLS 1.2 to TLS 1.3 in backup configs for current security best practices.

---

## What Was Backed Up

### ARM Template
- `arm-templates/FFC-ChatBot-template.json` — Full resource group ARM template with all 13 resources

> **Note:** The ARM template uses several preview API versions (e.g., `2024-11-01-preview`, `2025-05-01-preview`). These may no longer be available at restore time; update `apiVersion` values to currently supported versions if deployment fails.

> **Note:** The `customDomainVerificationId` value in the ARM template is **subscription-specific**. If restoring to a different subscription, this value will need to be regenerated (it is auto-assigned by Azure).

> **Note:** The container registry password is not included in the ARM template (exported as null for security). You must configure registry credentials manually after deployment — see Step 4 below.

### App Service Web Apps (2)
- `app-settings/FFC-ChatBot-bot-78ac-settings.json` — App settings (secrets redacted)
- `app-settings/FFC-ChatBot-bot-78ac-config.json` — Runtime/framework config
- `app-settings/FFC-ChatBot-bot-5ebe-settings.json` — App settings (secrets redacted)
- `app-settings/FFC-ChatBot-bot-5ebe-config.json` — Runtime/framework config

### Bot Services (3)
- `bot-configs/FFC-ChatBot-bot.json` — Bot Service (S1)
- `bot-configs/FFC-BotChatBot.json` — Bot Service (S1)
- `bot-configs/ffc-chatbot-2025.json` — Bot Service (F0)

### AI Services
- `bot-configs/cognitive-services-FFC-ChatBot.json` — Text Analytics (F0)
- `bot-configs/search-service.json` — Azure Cognitive Search (Free)

### Container Infrastructure
- `container/ffc-influence-ai-bot.json` — Container Instance config (metadata only — see note below)
- `container/acr-config.json` — Container Registry (Basic) config
- `container/acr-repositories.json` — Repository list
- `container/acr-tags-ffc-influence-ai-bot.txt` — Image tags

> **Container Image Backup:** The actual Docker image has been pushed to GitHub Container Registry:
> ```
> ghcr.io/freeforcharity/ffc-influence-ai-bot:v1
> ```
> To pull it: `docker pull ghcr.io/freeforcharity/ffc-influence-ai-bot:v1`
>
> This is a full backup of the original ACR image (`ffcregistry-dzayc6hfgmbahtbj.azurecr.io/ffc-influence-ai-bot:v1`).
> If you need to push it to a new Azure Container Registry:
> ```bash
> docker pull ghcr.io/freeforcharity/ffc-influence-ai-bot:v1
> docker tag ghcr.io/freeforcharity/ffc-influence-ai-bot:v1 <new-registry>.azurecr.io/ffc-influence-ai-bot:v1
> az acr login --name <new-registry>
> docker push <new-registry>.azurecr.io/ffc-influence-ai-bot:v1
> ```

### Managed Identities (2)
- `bot-configs/identity-FFC-ChatBot-bot.json`
- `bot-configs/identity-FFC-BotChatBot.json`

### Bot Source Code
The original bot source code is in this repo under `FFC QnA Bot Source/` (C# .NET QnA Maker bot).

---

## How to Restore

### Prerequisites

1. Azure CLI installed and logged in: `az login`
2. Active subscription with sufficient credits
3. PowerShell 7+ recommended
4. Docker installed (if you need to pull/push container images)

### Step 1: Recreate the Resource Group

```bash
az group create --name FFC-ChatBot --location eastus
```

### Step 2: Deploy the ARM Template

```bash
az deployment group create \
  --resource-group FFC-ChatBot \
  --template-file azure-backup/arm-templates/FFC-ChatBot-template.json
```

**Notes:**
- The ARM template will prompt for parameter values. Review and accept defaults or customize as needed.
- Some resources (like Bot Services with specific names) may need adjusted names if the originals still exist in soft-deleted state.
- The template uses several preview/future API versions (e.g., `2024-11-01-preview`, `2025-05-01-preview`). If deployment fails with API version errors, update the `apiVersion` values in the template to currently supported versions. Check available versions with: `az provider show --namespace Microsoft.ContainerInstance --query "resourceTypes[?resourceType=='containerGroups'].apiVersions" -o table`
- The `customDomainVerificationId` in the template is subscription-specific and will be auto-regenerated by Azure if deploying to a different subscription.

### Step 3: Reconfigure App Settings

After the web apps are deployed, restore the application settings:

```powershell
# For each web app, restore settings from backup
$webApps = @(
    @{ Name = "FFC-ChatBot-bot-78ac"; File = "azure-backup/app-settings/FFC-ChatBot-bot-78ac-settings.json" },
    @{ Name = "FFC-ChatBot-bot-5ebe"; File = "azure-backup/app-settings/FFC-ChatBot-bot-5ebe-settings.json" }
)

foreach ($app in $webApps) {
    $settings = Get-Content $app.File -Raw | ConvertFrom-Json
    if (-not $settings) {
        Write-Error "Failed to parse settings from $($app.File)"
        continue
    }

    foreach ($s in $settings) {
        if ([string]::IsNullOrWhiteSpace($s.name) -or [string]::IsNullOrWhiteSpace($s.value)) {
            Write-Warning "Skipping empty setting in $($app.Name)"
            continue
        }
        if ($s.value -eq "REDACTED-FOR-SECURITY-SEE-AZURE-PORTAL") {
            Write-Warning "Skipping redacted setting '$($s.name)' — set manually in Azure Portal"
            continue
        }
        az webapp config appsettings set `
          --name $app.Name `
          --resource-group FFC-ChatBot `
          --settings "$($s.name)=$($s.value)"
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to set '$($s.name)' on $($app.Name)"
        }
    }
}
```

**IMPORTANT:** Settings marked `REDACTED-FOR-SECURITY-SEE-AZURE-PORTAL` must be manually set:

| Setting | How to Get the Value |
|---------|---------------------|
| `LanguageEndpointKey` | Azure Portal → Cognitive Services → `FFC-ChatBot` → Keys and Endpoint |

### Step 4: Rebuild Container Image

The container image has been backed up to GitHub Container Registry. To restore:

1. Recreate the registry: `az acr create --name ffcregistry --resource-group FFC-ChatBot --sku Basic`
2. Configure registry credentials (admin user or managed identity):
   ```bash
   az acr update --name ffcregistry --admin-enabled true
   ```
3. Pull the backed-up image from GHCR and push to the new ACR:
   ```bash
   docker pull ghcr.io/freeforcharity/ffc-influence-ai-bot:v1
   docker tag ghcr.io/freeforcharity/ffc-influence-ai-bot:v1 ffcregistry.azurecr.io/ffc-influence-ai-bot:v1
   az acr login --name ffcregistry
   docker push ffcregistry.azurecr.io/ffc-influence-ai-bot:v1
   ```
4. Recreate the Container Instance:

```bash
# Recreate container instance (adjust image reference if registry name changed)
az container create \
  --resource-group FFC-ChatBot \
  --name ffc-influence-ai-bot \
  --image ffcregistry.azurecr.io/ffc-influence-ai-bot:v1 \
  --registry-login-server ffcregistry.azurecr.io \
  --registry-username ffcregistry \
  --registry-password <acr-password> \
  --cpu 1 \
  --memory 1.5 \
  --ports 3978
```

> **Warning:** The original container had **16,013 restarts**, indicating it was in a crash loop. Investigate and fix the underlying issue (check logs, dependencies, environment variables) before redeploying the container.

### Step 5: Verify Bot Registration

After deployment, verify bot services are registered and endpoints are correct:

```bash
az bot show --name FFC-ChatBot-bot --resource-group FFC-ChatBot
```

Update the messaging endpoint if the web app URL changed.

---

## Resource Inventory at Time of Backup

| Resource | Type | SKU | Monthly Cost |
|----------|------|-----|-------------|
| FFC-ChatBot-serverfarm-2f27ad | App Service Plan | S1 | ~$45 |
| FFC-ChatBot-serverfarm-77b5b5 | App Service Plan | S1 | ~$45 |
| ffc-influence-ai-bot | Container Instance | 1 CPU/1.5 GB | ~$21 |
| Microsoft Defender for Cloud | Security | — | ~$18 |
| ffcregistry | Container Registry | Basic | ~$3 |
| FFC-ChatBot-bot | Bot Service | S1 | ~$0.15 |
| FFC-BotChatBot | Bot Service | S1 | ~$0.15 |
| ffc-chatbot-2025 | Bot Service | F0 | $0 |
| FFC-ChatBot | Cognitive Services | F0 | $0 |
| ffcchatbot-asa2wtzul6bmew6 | Search Service | Free | $0 |
| FFC-ChatBot-bot (identity) | Managed Identity | — | $0 |
| FFC-BotChatBot (identity) | Managed Identity | — | $0 |
| **Total** | | | **~$134/mo** |

---

## Managed Identity Details

These identities were used for bot authentication (UserAssignedMSI):

| Identity | Client ID | Used By |
|----------|-----------|---------|
| FFC-ChatBot-bot | `99202ead-618d-48e9-8cbd-c83b834d8ee9` | FFC-ChatBot-bot-78ac web app |
| FFC-BotChatBot | `e1afff62-15df-4951-abb0-0981172dc691` | FFC-ChatBot-bot-5ebe web app |

**Note:** When restoring, new managed identities will get new client IDs. Update `MicrosoftAppId` in app settings accordingly.

---

## Cost Savings

Shutting down these resources saves **~$134/month** (**~$1,600/year**) in Azure Sponsorship credits.

---

## Questions?

Contact Clarke Moyer — these resources were part of the FFC Microsoft Bot initiative. See the main repo README and `FFC QnA Bot Source/README.md` for bot architecture details.
