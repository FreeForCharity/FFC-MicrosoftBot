# FFC ChatBot — Azure Restore Guide

**Backup Date:** February 20, 2026
**Subscription:** FFC - Microsoft Azure Sponsorship (`dea314c6-800f-4410-a095-415d4c83d681`)
**Tenant:** Free For Charity (`80c64bf2-fa5b-425c-9a5a-1fcf282d3274`)
**Resource Group:** `FFC-ChatBot` (East US)

---

## Why This Was Shut Down

The chatbot infrastructure was **not actively in use** but cost **~$134/month** (~$1,600/year). All resources were exported and archived here before deletion to free up Azure Sponsorship credits.

---

## What Was Backed Up

### ARM Template
- `arm-templates/FFC-ChatBot-template.json` — Full resource group ARM template with all 13 resources

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
- `container/ffc-influence-ai-bot.json` — Container Instance config (image: `ffcregistry.../ffc-influence-ai-bot:v1`)
- `container/acr-config.json` — Container Registry (Basic) config
- `container/acr-repositories.json` — Repository list
- `container/acr-tags-ffc-influence-ai-bot.txt` — Image tags

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

**Note:** The ARM template will prompt for parameter values. Review and accept defaults or customize as needed. Some resources (like Bot Services with specific names) may need adjusted names if the originals still exist in soft-deleted state. This template also uses several preview/future API versions, which may no longer be available at the time of restoration; if deployment fails with API version-related errors, update the affected `apiVersion` values to currently supported versions and retry.

### Step 3: Reconfigure App Settings

After the web apps are deployed, restore the application settings:

```powershell
# For FFC-ChatBot-bot-78ac
$settings = Get-Content "azure-backup/app-settings/FFC-ChatBot-bot-78ac-settings.json" | ConvertFrom-Json
foreach ($s in $settings) {
    if ($s.value -ne "REDACTED-FOR-SECURITY-SEE-AZURE-PORTAL") {
        az webapp config appsettings set `
          --name FFC-ChatBot-bot-78ac `
          --resource-group FFC-ChatBot `
          --settings "$($s.name)=$($s.value)"
    }
}
```

**IMPORTANT:** Settings marked `REDACTED-FOR-SECURITY-SEE-AZURE-PORTAL` must be manually set:

| Setting | How to Get the Value |
|---------|---------------------|
| `LanguageEndpointKey` | Azure Portal → Cognitive Services → `FFC-ChatBot` → Keys and Endpoint |

### Step 4: Rebuild Container Image

The container image was stored in Azure Container Registry (`ffcregistry`). If the registry was deleted, you'll need to:

1. Recreate the registry: `az acr create --name ffcregistry --resource-group FFC-ChatBot --sku Basic`
2. Rebuild and push the container image from source
3. Recreate the Container Instance using the config in `container/ffc-influence-ai-bot.json`

```bash
# Recreate container instance (adjust image reference if registry name changed)
az container create \
  --resource-group FFC-ChatBot \
  --name ffc-influence-ai-bot \
  --image ffcregistry.azurecr.io/ffc-influence-ai-bot:v1 \
  --cpu 1 \
  --memory 1.5 \
  --ports 3978
```

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
