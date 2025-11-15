# sfdcJuice

**Search Helpjuice and Salesforce Knowledge articles from one place in Salesforce.**

sfdcJuice lets your support team search both Helpjuice knowledge base and Salesforce Knowledge articles without leaving Salesforce. Everything works in the standard Salesforce interface you already know.

---

## ✨ What Can You Do?

- **Search Everything**: Find articles from both Helpjuice and Salesforce Knowledge with one search
- **Filter by Source**: Choose to search All sources, Helpjuice only, or Salesforce only
- **View Articles**: Click any article to read the full content in a popup window
- **Works Everywhere**: Works in standard Salesforce pages and Service Console

---

## 📦 Installation

### Prerequisites

Before you start, make sure you have:
- ✅ A Salesforce org with Knowledge enabled
- ✅ A Helpjuice account with API access
- ✅ Your Helpjuice API key (get it from Helpjuice Settings → API Credentials)

### Install sfdcJuice (One Click)

Click the button below to install sfdcJuice in your Salesforce org:

**[👉 Click here to install sfdcJuice](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tgK0000007IRdQAM)**

**What happens:**
1. Click the button above
2. Log in to your Salesforce org
3. Click **Install for All Users** (or **Install for Admins Only** if you prefer)
4. Wait for installation to complete (usually takes 1-2 minutes)
5. Click **Done** when finished

**After installation, continue to the Configuration steps below.**

---

## ⚙️ Configuration (Required After Installation)

After installing the package, you **must** complete these steps before sfdcJuice will work. We recommend using **Named Credentials** (Option A) for better security, but you can also use Custom Metadata with Remote Site Settings (Option B).

### Option A: Named Credentials (Recommended - More Secure)

This option uses Salesforce Named Credentials to securely store your API endpoint and eliminates the need for Remote Site Settings.

#### Step 1: Create Named Credential (5 minutes)

1. Go to **Setup** (gear icon in top right)
2. In Quick Find, type: `Named Credentials`
3. Click **Named Credentials**
4. Find **Helpjuice_API** and click **Edit** (or create a new one if it doesn't exist)
5. Fill in these fields:

   | Field | What to Enter |
   |-------|---------------|
   | **Label** | `Helpjuice API` |
   | **Name** | `Helpjuice_API` (must match exactly) |
   | **URL** | Your Helpjuice domain (e.g., `https://yourcompany.helpjuice.com`) |
   | **Identity Type** | `Named Principal` |
   | **Authentication Protocol** | `No Authentication` |

6. Click **Save**

#### Step 2: Configure Custom Metadata (3 minutes)

1. Go to **Setup** → **Custom Metadata Types** → **sfdcJuice Config** → **Manage Records**
2. Open the **Default** record (or create it if it doesn't exist)
3. Fill in:

   | Field | What to Enter |
   |-------|---------------|
   | **Named Credential Name** | `Helpjuice_API` (must match the Named Credential name) |
   | **Helpjuice API Key** | Your Helpjuice API key (from Helpjuice → Settings → API Credentials) |
   | **Helpjuice Base URL** | Your Helpjuice URL (for fallback if Named Credential is not used) |
   | **Is Active** | ☑️ Check this box |
   | **Max Results Per Source** | `25` |
   | **Request Timeout (Seconds)** | `30` |

4. Click **Save**

> **🔒 Security**: Enable Platform Encryption on the **Helpjuice API Key** field for additional security. Go to Setup → Platform Encryption → Field Encryption and enable encryption for `sfdcJuice_Config__mdt.Helpjuice_API_Key__c`. This encrypts the API key at rest, preventing it from being visible in logs or database queries.

#### Step 3: Add Trusted URL for Images (Required for Images to Work)

For images in Helpjuice articles to display correctly, you need to add a Trusted URL:

1. Go to **Setup** → **Security** → **CSP Trusted Sites** (or **Trusted URLs for LockerService**)
2. Find **Helpjuice_Images** (it should already exist from the deployment)
3. If it doesn't exist, click **New Trusted URL**
4. Fill in:
   - **Name**: `Helpjuice Images`
   - **URL**: `https://*.helpjuice.com`
   - **Active**: ✅ Check this box
5. Click **Save**

> **📸 Important**: Without this Trusted URL, images in Helpjuice articles will not display in the article viewer.

### Option B: Custom Metadata with Remote Site Settings (Alternative)

If you prefer not to use Named Credentials, you can use Custom Metadata directly.

#### Step 1: Configure Custom Metadata (5 minutes)

1. Go to **Setup** → **Custom Metadata Types** → **sfdcJuice Config** → **Manage Records**
2. Open the **Default** record (or create it if it doesn't exist)
3. Fill in:

   | Field | What to Enter | Where to Get It |
   |-------|---------------|-----------------|
   | **Helpjuice API Key** | Your Helpjuice API key | Helpjuice → Settings → API Credentials |
   | **Helpjuice Base URL** | Your Helpjuice URL | Example: `https://yourcompany.helpjuice.com` |
   | **Is Active** | ☑️ Check this box | Must be checked to work |
   | **Max Results Per Source** | `25` | Default is fine |
   | **Request Timeout (Seconds)** | `30` | Default is fine |

4. Click **Save**

> **🔒 Security**: Enable Platform Encryption on the **Helpjuice API Key** field for additional security. Go to Setup → Platform Encryption → Field Encryption and enable encryption for `sfdcJuice_Config__mdt.Helpjuice_API_Key__c`.

#### Step 2: Add Remote Site Settings (3 minutes)

Salesforce needs permission to call the Helpjuice API. This step tells Salesforce it's okay.

1. Go to **Setup** → **Security** → **Remote Site Settings**
2. Click **New Remote Site**
3. Fill in:

   | Field | What to Enter |
   |-------|---------------|
   | **Remote Site Name** | `Helpjuice_API` (or any name you like) |
   | **Remote Site URL** | Your Helpjuice domain (same as Step 1) |
   | **Disable Protocol Security** | ❌ Leave unchecked |
   | **Active** | ☑️ Check this box |

   **Example**: If your Helpjuice Base URL is `https://acme.helpjuice.com`, enter `https://acme.helpjuice.com` in the Remote Site URL field.

4. Click **Save**

> **⚠️ Important**: The Remote Site URL must **exactly match** your Helpjuice domain. If they don't match, Helpjuice searches won't work.

#### Step 3: Add Trusted URL for Images (Required for Images to Work)

For images in Helpjuice articles to display correctly, you need to add a Trusted URL:

1. Go to **Setup** → **Security** → **CSP Trusted Sites** (or **Trusted URLs for LockerService**)
2. Find **Helpjuice_Images** (it should already exist from the deployment)
3. If it doesn't exist, click **New Trusted URL**
4. Fill in:
   - **Name**: `Helpjuice Images`
   - **URL**: `https://*.helpjuice.com`
   - **Active**: ✅ Check this box
5. Click **Save**

> **📸 Important**: Without this Trusted URL, images in Helpjuice articles will not display in the article viewer.

---

## 🚀 Add the Component to a Page

Now that everything is configured, add the search component to a Lightning page. sfdcJuice includes two components you can use:

### Option 1: unifiedSearch (Full Page Component)

Use this component for a full-width search interface on app pages or home pages.

1. Go to any **Lightning App Page** or **Home Page**
2. Click the **⚙️ Settings** icon (top right) → **Edit Page**
3. In the component list (left side), find **unifiedSearch**
4. Drag **unifiedSearch** onto your page
5. Click **Save** (top right)
6. Click **Activate** (if needed)

### Option 2: unifiedSearchSidebar (Sidebar Component)

Use this component for a compact sidebar search on record pages, app pages, or community pages.

1. Go to any **Lightning Record Page**, **App Page**, or **Community Page**
2. Click the **⚙️ Settings** icon (top right) → **Edit Page**
3. In the component list (left side), find **unifiedSearchSidebar**
4. Drag **unifiedSearchSidebar** onto your page (typically in a sidebar region)
5. Click **Save** (top right)
6. Click **Activate** (if needed)

**Which component should you use?**
- **unifiedSearch**: Use for dedicated search pages or when you want a full-width search experience
- **unifiedSearchSidebar**: Use in sidebars on record pages or when you want search always accessible while viewing other content

Both components have the same functionality - search, filter by source, and view articles.

---

## 📖 How to Use

### Basic Search

1. Type your search query in the search box
2. Click **Search** or press **Enter**
3. Results from both Helpjuice and Salesforce Knowledge appear

### Filter by Source

Use the radio buttons to choose what to search:
- **All Sources**: Searches both Helpjuice and Salesforce Knowledge
- **Helpjuice**: Searches only Helpjuice articles
- **Salesforce**: Searches only Salesforce Knowledge articles

### View an Article

Click any article card to open it in a popup window. You can:
- Read the full article
- Open the article in a new tab/window
- Copy the article link

---

## 🐛 Troubleshooting

### Helpjuice Articles Aren't Showing Up

If you see Salesforce Knowledge articles but not Helpjuice articles, check these:

#### ✅ Check Your Configuration

**If using Named Credentials:**
- Go to **Setup** → **Named Credentials**
- Find **Helpjuice_API** and verify:
  - **URL** matches your Helpjuice domain (e.g., `https://yourcompany.helpjuice.com`)
  - **Name** is exactly `Helpjuice_API`
- Go to **Setup** → **Custom Metadata Types** → **sfdcJuice Config** → **Manage Records**
- Open the **Default** record and verify:
  - **Named Credential Name** is set to `Helpjuice_API`
  - **Helpjuice API Key** has your API key (this will be encrypted if Platform Encryption is enabled)
  - **Is Active** is checked ✅

**If using Custom Metadata only:**
- Go to **Setup** → **Custom Metadata Types** → **sfdcJuice Config** → **Manage Records**
- Open the **Default** record
- Make sure:
  - **Helpjuice API Key** has your real API key (not placeholder text)
  - **Helpjuice Base URL** has your real Helpjuice URL (like `https://yourcompany.helpjuice.com`)
  - **Is Active** is checked ✅

**If it's wrong:**
- Edit the record and update the values
- Click **Save**

#### ✅ Check Your Remote Site Settings (Only if not using Named Credentials)

**What to look for:**
- Go to **Setup** → **Security** → **Remote Site Settings**
- Find your Remote Site (the one you created)
- Click **Edit**
- Make sure:
  - **Remote Site URL** exactly matches your Helpjuice Base URL
  - **Active** is checked ✅

**If it's wrong:**
- Edit the Remote Site URL to match your Helpjuice domain exactly
- Make sure it's active
- Click **Save**

> **Note**: If you're using Named Credentials, Remote Site Settings are not required.

#### ✅ Check Your API Key

**What to check:**
- Go to Helpjuice → **Settings** → **API Credentials**
- Verify your API key is correct and active
- Copy the API key again and update your Custom Metadata record

#### ✅ Common Error Messages

| Error Message | What It Means | How to Fix |
|---------------|---------------|------------|
| "Unauthorized endpoint" or "Remote Site Settings not configured" | Salesforce can't reach Helpjuice | If using Custom Metadata only: Add or fix your Remote Site Settings. If using Named Credential: Verify Named Credential is configured correctly |
| "Configuration has placeholder values" | Custom Metadata isn't set up | Update Custom Metadata with real values, or configure Named Credential |
| "Helpjuice API error: 401" | Invalid API key | Check your API key in Named Credential Identity or Custom Metadata |
| "Helpjuice API error: 404" | Wrong Base URL | Verify your Base URL in Named Credential or Custom Metadata matches your Helpjuice domain exactly |

---

## 🔒 Security

- **API Key Encryption**: API keys are stored securely using one of these methods:
  - **Named Credentials (Recommended)**: Using Named Credentials for the endpoint eliminates the need for Remote Site Settings and provides better endpoint security
  - **Platform Encryption**: Enable Platform Encryption on the `Helpjuice_API_Key__c` Custom Metadata field to encrypt the API key at rest. This prevents the API key from being visible in logs, debug statements, or database queries
- **Secure Endpoints**: Named Credentials eliminate the need for Remote Site Settings and provide better security
- **Input Validation**: All user input is validated and sanitized
- **Secure Headers**: API keys are sent in the Authorization header, not in URL parameters

---

## 🆘 Need Help?

- **Found a bug?** Open an issue on GitHub
- **Questions?** Check the [Helpjuice API Documentation](https://help.helpjuice.com/en_US/api-v3/using-api-v3)
- **Salesforce Help?** Check the [Salesforce Knowledge Documentation](https://help.salesforce.com/s/articleView?id=sf.knowledge.htm)

---

## 🤝 Contributing

This is an open-source project. We welcome contributions!

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

---

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**Built with ❤️ for the Salesforce community**
