# 🔐 Security Review Automation

Este projeto possui duas formas de revisão automática de segurança.

## 1) GitHub Actions (automático em push/PR)

Arquivo: `.github/workflows/security-review.yml`

Executa:
- Scan de segredos com Gitleaks
- `npm ci` no backend
- `node -c server.js`
- `npm audit --omit=dev --audit-level=high`
- bloqueio se `.env` estiver versionado

## 2) Script local (antes de deploy)

Arquivo: `scripts/secure-review.sh`

Executa as mesmas validações principais localmente.

### Uso

```bash
bash scripts/secure-review.sh
```

## Recomendações

- Nunca commitar `.env`
- Se uma chave vazar, rotacionar imediatamente
- Rodar revisão local antes de `git push`
- Revisar falhas do workflow antes de merge
