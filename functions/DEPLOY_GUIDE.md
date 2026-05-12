# 📧 Guia de Deploy — E-mail automático de aprovação

## O que faz
Quando você aprovar um usuário no Painel Admin, ele recebe automaticamente
um e-mail bonito de boas-vindas com os recursos do MedCases Pro.

---

## PASSO 1 — Criar App Password no Gmail

> ⚠️ Não use sua senha normal do Gmail. Crie uma "Senha de App" específica.

1. Acesse: **https://myaccount.google.com/security**
2. Ative **"Verificação em duas etapas"** (se ainda não estiver ativa)
3. Pesquise **"Senhas de app"** na barra de busca da conta Google
4. Clique em **"Senhas de app"**
5. Em "Selecionar app" → escolha **"Outro (nome personalizado)"**
6. Digite: `MedCases Pro`
7. Clique em **Gerar**
8. **Copie a senha de 16 caracteres** (ex: `abcd efgh ijkl mnop`)
9. Guarde — só aparece uma vez!

---

## PASSO 2 — Instalar Firebase CLI (se ainda não tiver)

```bash
npm install -g firebase-tools
```

---

## PASSO 3 — Login no Firebase CLI

```bash
firebase login
```

Abrirá o navegador — faça login com a conta do projeto `medcases-pro`.

---

## PASSO 4 — Instalar dependências da Function

```bash
cd functions
npm install
cd ..
```

---

## PASSO 5 — Configurar credenciais Gmail na Function

```bash
firebase functions:config:set \
  gmail.user="medcasespro@gmail.com" \
  gmail.pass="COLE_AQUI_A_SENHA_DE_16_CARACTERES_SEM_ESPAÇOS"
```

Exemplo real:
```bash
firebase functions:config:set gmail.user="medcasespro@gmail.com" gmail.pass="abcdefghijklmnop"
```

---

## PASSO 6 — Deploy da Function

```bash
firebase deploy --only functions
```

Aguarde ~2 minutos. Ao terminar você verá:
```
✔ functions[onUserApproved]: Successful create operation.
✔ functions[onUserUnblocked]: Successful create operation.
```

---

## PASSO 7 — Testar

1. Abra o **Painel Admin** no app
2. Aprove qualquer usuário pendente
3. O e-mail chega em segundos na caixa do usuário ✅

---

## Como funciona (resumo técnico)

```
Admin clica "Aprovar"
       ↓
Firestore: users/{uid}.status = "approved"
       ↓
Cloud Function detecta a mudança (onUpdate trigger)
       ↓
Nodemailer envia e-mail via Gmail SMTP
       ↓
Usuário recebe boas-vindas ✅
```

---

## Dúvidas?

Qualquer problema no deploy é só chamar. 🩺
