# Migration Guide: Encrypting API Keys with Named Credentials

This guide walks you through migrating from the old configuration (Custom Metadata + Remote Site Settings) to the new secure configuration (Named Credentials + Platform Encryption).

## 📋 What Changed

- **New Field Added**: `Named_Credential_Name__c` in Custom Metadata
- **New Named Credential**: `Helpjuice_API` for secure endpoint configuration
- **Code Updates**: Services now support both Named Credentials and Custom Metadata (backward compatible)

## ✅ Migration Steps

### Step 1: Configure Named Credential (Recommended)

1. Go to **Setup** → **Named Credentials**
2. Find **Helpjuice_API** (it should already exist from the deployment)
3. Click **Edit**
4. Update the **URL** field with your Helpjuice domain:
   - Example: `https://yourcompany.helpjuice.com`
5. Set:
   - **Identity Type**: `Named Principal`
   - **Authentication Protocol**: `No Authentication`
6. Click **Save**

### Step 2: Update Custom Metadata

1. Go to **Setup** → **Custom Metadata Types** → **sfdcJuice Config** → **Manage Records**
2. Open the **Default** record
3. Fill in the new **Named Credential Name** field:
   - Enter: `Helpjuice_API` (must match exactly)
4. **Keep your existing values** in:
   - **Helpjuice API Key** (for fallback)
   - **Helpjuice Base URL** (for fallback)
5. Click **Save**

### Step 3: Enable Platform Encryption (Highly Recommended)

1. Go to **Setup** → **Platform Encryption** → **Field Encryption**
2. Find `sfdcJuice_Config__mdt.Helpjuice_API_Key__c`
3. Enable encryption for this field
4. This encrypts the API key at rest, preventing it from appearing in logs or queries

> **Note**: Platform Encryption requires a license. If you don't have it, the API key will still work but won't be encrypted.

### Step 4: Add Trusted URL for Images (Required for Images to Work)

1. Go to **Setup** → **Security** → **Trusted URLs for LockerService**
2. Click **New Trusted URL**
3. Fill in:
   - **Name**: `Helpjuice Images`
   - **URL**: `https://*.helpjuice.com`
   - **Active**: ✅ Check this box
4. Click **Save**

### Step 5: Optional - Remove Remote Site Settings

**You can keep Remote Site Settings** - they won't interfere. However, if you want to clean up:

1. Go to **Setup** → **Security** → **Remote Site Settings**
2. Find your Helpjuice Remote Site (e.g., `Helpjuice_API`)
3. Click **Delete** (optional - only if you're fully using Named Credentials)

> **Important**: Only delete Remote Site Settings **after** you've verified that Named Credentials are working correctly.

## 🔄 Backward Compatibility

The code is **fully backward compatible**. It will:
- Use Named Credential if `Named_Credential_Name__c` is configured
- Fall back to Custom Metadata if Named Credential is not configured
- Work with or without Remote Site Settings

## ✅ Verification

After migration, test the search functionality:
1. Go to a page with the unifiedSearch component
2. Perform a search
3. Verify Helpjuice articles appear
4. Check that images in articles display correctly

## ❓ FAQ

**Q: Do I need to delete the Custom Metadata?**  
A: **No!** Keep your Custom Metadata record. It's used as a fallback and for storing other configuration values.

**Q: Do I need to delete Remote Site Settings?**  
A: **No, it's optional.** Remote Site Settings won't interfere. You can delete them later if you want, but only after verifying Named Credentials work.

**Q: What if I don't have Platform Encryption?**  
A: The solution will still work. The API key will be stored in Custom Metadata (not encrypted), but it won't be in code. For better security, consider enabling Platform Encryption.

**Q: Can I use both Named Credential and Custom Metadata?**  
A: Yes! The code will prefer Named Credential if configured, and fall back to Custom Metadata if needed.

