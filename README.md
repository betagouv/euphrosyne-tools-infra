# euphrosyne-tools-infra
Infrastructure as Code de mise à disposition des outils aux chercheurs NewAGLAE

#### Upgrade Bicep template
```bash
az ts create --name vmSpec --version "[version]" --resource-group [resourceGroupeName] --location "[location]" --template-file "./bicep/infra.bicep"
```