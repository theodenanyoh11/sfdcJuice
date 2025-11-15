import { LightningElement, api } from 'lwc';

export default class ArticleViewer extends LightningElement {
  @api article;
  @api isloading = false;
  contentElement;
  
  get isLoading() {
    return this.isloading;
  }

  // Show message when content is empty but URL is available
  get showContentEmptyMessage() {
    return !this.isloading && 
           this.article && 
           (!this.articleContent || this.articleContent.trim().length === 0) &&
           this.articleUrl && 
           this.articleUrl.length > 0;
  }

  renderedCallback() {
    // Render content whenever article or isloading changes
    // Always render parsed content (no iframe since Helpjuice blocks iframe embedding)
    if (!this.isloading && this.article) {
      // Check if content element exists before rendering
      const contentDiv = this.template.querySelector('.article-content');
      if (contentDiv) {
        this.renderContent();
      } else {
        // If element doesn't exist yet, wait a bit and try again
        setTimeout(() => {
          this.renderContent();
        }, 50);
      }
    }
  }

  get hasArticle() {
    return this.article != null;
  }

  get articleContent() {
    if (!this.article || !this.article.content) {
      return '';
    }
    // For Helpjuice, content may be HTML
    // For Salesforce, content may be Rich Text
    return this.article.content;
  }

  get articleUrl() {
    return this.article?.url || '';
  }

  get articleTitle() {
    return this.article?.title || '';
  }

  get articleSource() {
    return this.article?.source || '';
  }

  get articleTags() {
    return this.article?.tags || [];
  }

  get articleCategories() {
    return this.article?.categories || [];
  }

  get publishedDate() {
    if (!this.article?.publishedDate) return '';
    return new Date(this.article.publishedDate).toLocaleDateString();
  }

  get lastModifiedDate() {
    if (!this.article?.lastModifiedDate) return '';
    return new Date(this.article.lastModifiedDate).toLocaleDateString();
  }

  get authorName() {
    return this.article?.authorName || '';
  }

  get badgeClass() {
    return this.articleSource === 'Helpjuice' ? 'slds-badge_inverse' : '';
  }

  handleClose() {
    const closeEvent = new CustomEvent('close');
    this.dispatchEvent(closeEvent);
  }

  handleOpenExternal() {
    if (this.articleUrl) {
      window.open(this.articleUrl, '_blank');
    }
  }

  handleLinkToCase() {
    // This would integrate with Case linking functionality
    // For now, dispatch an event that can be handled by parent
    const linkEvent = new CustomEvent('linktocase', {
      detail: { article: this.article }
    });
    this.dispatchEvent(linkEvent);
    this.handleClose();
  }


  /**
   * Extract base URL from article URL
   * Example: https://account.helpjuice.com/article-slug -> https://account.helpjuice.com
   */
  getBaseUrl(url) {
    if (!url) return null;
    try {
      const urlObj = new URL(url);
      return `${urlObj.protocol}//${urlObj.host}`;
    } catch (e) {
      console.warn('Failed to parse URL:', url, e);
      return null;
    }
  }

  /**
   * Convert relative URL to absolute URL using base URL
   */
  makeAbsoluteUrl(src, baseUrl) {
    if (!src || !baseUrl) return src;
    
    // If already absolute (starts with http:// or https://), return as-is
    if (src.startsWith('http://') || src.startsWith('https://')) {
      return src;
    }
    
    // If protocol-relative (starts with //), add protocol from base URL
    if (src.startsWith('//')) {
      try {
        const baseUrlObj = new URL(baseUrl);
        return `${baseUrlObj.protocol}${src}`;
      } catch (e) {
        return src;
      }
    }
    
    // If absolute path (starts with /), combine with base URL
    if (src.startsWith('/')) {
      return baseUrl + src;
    }
    
    // Otherwise, it's a relative path - combine with base URL + /
    // For Helpjuice, relative images are typically relative to the root
    return baseUrl + '/' + src;
  }

  renderContent() {
    // Wait a tick to ensure DOM is ready
    setTimeout(() => {
      const contentDiv = this.template.querySelector('.article-content');
      console.log('renderContent called. contentDiv:', contentDiv, 'articleContent:', this.articleContent, 'isloading:', this.isloading);
      if (contentDiv && this.articleContent && this.articleContent.trim().length > 0 && !this.isloading) {
        console.log('Rendering content. Length:', this.articleContent.length);
        
        // Get base URL from article URL (for Helpjuice articles)
        const baseUrl = this.articleSource === 'Helpjuice' && this.articleUrl 
          ? this.getBaseUrl(this.articleUrl)
          : null;
        
        // Set innerHTML to render HTML content (including images and rich text)
        // LWC's lwc:dom="manual" allows us to set innerHTML for trusted content
        contentDiv.innerHTML = this.articleContent;
        console.log('Content rendered. innerHTML length:', contentDiv.innerHTML.length);
        
        // Fix image URLs - convert relative URLs to absolute URLs
        const images = contentDiv.querySelectorAll('img');
        console.log('Found', images.length, 'images in content');
        images.forEach((img) => {
          const originalSrc = img.getAttribute('src');
          console.log('Image original src:', originalSrc);
          
          // Convert relative URLs to absolute URLs using base URL
          if (baseUrl && originalSrc) {
            const absoluteSrc = this.makeAbsoluteUrl(originalSrc, baseUrl);
            if (absoluteSrc !== originalSrc) {
              console.log('Converting image URL from', originalSrc, 'to', absoluteSrc);
              img.setAttribute('src', absoluteSrc);
            }
          }
          
          // Handle srcset attribute for responsive images
          const srcset = img.getAttribute('srcset');
          if (baseUrl && srcset) {
            // Parse srcset and convert relative URLs to absolute
            // Format: "image1.jpg 1x, image2.jpg 2x" or "image1.jpg 300w, image2.jpg 600w"
            const srcsetParts = srcset.split(',');
            const absoluteSrcset = srcsetParts.map(part => {
              const trimmedPart = part.trim();
              const spaceIndex = trimmedPart.indexOf(' ');
              if (spaceIndex > 0) {
                const url = trimmedPart.substring(0, spaceIndex);
                const descriptor = trimmedPart.substring(spaceIndex);
                const absoluteUrl = this.makeAbsoluteUrl(url, baseUrl);
                return absoluteUrl + descriptor;
              } else {
                return this.makeAbsoluteUrl(trimmedPart, baseUrl);
              }
            }).join(', ');
            if (absoluteSrcset !== srcset) {
              console.log('Converting srcset from', srcset, 'to', absoluteSrcset);
              img.setAttribute('srcset', absoluteSrcset);
            }
          }
          
          // Ensure images have proper attributes
          if (!img.getAttribute('loading')) {
            img.setAttribute('loading', 'lazy');
          }
          if (!img.getAttribute('alt')) {
            img.setAttribute('alt', 'Article image');
          }
          
          // Add error handler for broken images
          img.onerror = function() {
            console.warn('Failed to load image:', this.src);
            // Optionally show a placeholder or error message
            this.style.border = '1px solid #d8dde6';
            this.style.backgroundColor = '#f3f2f2';
          };
          
          // Ensure images are styled properly
          img.style.maxWidth = '100%';
          img.style.height = 'auto';
          img.style.display = 'block';
          img.style.margin = '1rem 0';
        });
        
        // Fix other asset URLs (links, iframes, etc.) if needed
        // Fix links with relative URLs
        const links = contentDiv.querySelectorAll('a[href]');
        links.forEach((link) => {
          const href = link.getAttribute('href');
          if (baseUrl && href && !href.startsWith('http://') && !href.startsWith('https://') && !href.startsWith('mailto:') && !href.startsWith('#')) {
            const absoluteHref = this.makeAbsoluteUrl(href, baseUrl);
            if (absoluteHref !== href) {
              link.setAttribute('href', absoluteHref);
            }
          }
        });
        
        // Handle iframes (for embedded content like videos)
        const iframes = contentDiv.querySelectorAll('iframe');
        console.log('Found', iframes.length, 'iframes in content');
        iframes.forEach((iframe) => {
          const src = iframe.getAttribute('src');
          if (baseUrl && src && !src.startsWith('http://') && !src.startsWith('https://')) {
            const absoluteSrc = this.makeAbsoluteUrl(src, baseUrl);
            if (absoluteSrc !== src) {
              iframe.setAttribute('src', absoluteSrc);
            }
          }
          
          // Ensure iframes have proper attributes
          if (!iframe.getAttribute('sandbox')) {
            // Add sandbox attribute for security, but allow scripts and same-origin
            iframe.setAttribute('sandbox', 'allow-scripts allow-same-origin allow-presentation');
          }
          if (!iframe.getAttribute('loading')) {
            iframe.setAttribute('loading', 'lazy');
          }
        });
      } else {
        console.warn('Cannot render content. contentDiv:', !!contentDiv, 'articleContent:', !!this.articleContent, 'contentLength:', this.articleContent ? this.articleContent.length : 0, 'isloading:', this.isloading);
        if (contentDiv && (!this.articleContent || this.articleContent.trim().length === 0)) {
          contentDiv.innerHTML = '<p class="slds-text-body_regular slds-text-color_weak">No content available for this article.</p>';
        }
      }
    }, 100); // Increased timeout slightly to ensure DOM is ready
  }
}

