import { LightningElement, track } from 'lwc';
import searchArticles from '@salesforce/apex/UnifiedSearchService.search';
import getPopularArticles from '@salesforce/apex/UnifiedSearchService.getPopularArticles';
import getCategories from '@salesforce/apex/UnifiedSearchService.getCategories';
import getArticle from '@salesforce/apex/UnifiedSearchService.getArticle';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class UnifiedSearch extends LightningElement {
  @track searchQuery = '';
  @track sourceFilter = 'All';
  @track articles = [];
  @track isLoading = false;
  @track hasError = false;
  @track errorMessage = '';
  @track totalCount = 0;
  @track currentPage = 1;
  @track totalPages = 1;
  @track hasMore = false;

  // Filter options
  @track selectedTags = [];
  @track selectedCategories = [];
  @track dateFrom = null;
  @track dateTo = null;

  // Available filter values (populated from results)
  @track availableTags = [];
  @track availableCategories = [];

  // UI state
  @track selectedArticle = null;
  @track showArticleModal = false;
  @track isLoadingArticle = false;

  // Popular articles and categories (shown when no search query)
  @track popularArticles = [];
  @track categories = [];
  @track isLoadingPopular = false;

  get sourceOptions() {
    return [
      { label: 'All Sources', value: 'All' },
      { label: 'Helpjuice', value: 'Helpjuice' },
      { label: 'Salesforce', value: 'Salesforce' }
    ];
  }

  get hasResults() {
    return this.articles && this.articles.length > 0;
  }

  get showPopularArticles() {
    return !this.hasResults && this.popularArticles && this.popularArticles.length > 0;
  }

  get showCategories() {
    return !this.hasResults && this.categories && this.categories.length > 0;
  }

  get hasFilters() {
    return (
      this.selectedTags.length > 0 ||
      this.selectedCategories.length > 0 ||
      this.dateFrom ||
      this.dateTo
    );
  }

  get canGoPrevious() {
    return this.currentPage > 1;
  }

  get canGoNext() {
    return this.currentPage < this.totalPages;
  }

  get isPreviousDisabled() {
    return !this.canGoPrevious;
  }

  get isNextDisabled() {
    return !this.canGoNext;
  }

  handleSearchInputChange(event) {
    this.searchQuery = event.target.value;
    // If search query is cleared, reload popular content
    if (!this.searchQuery || this.searchQuery.trim().length === 0) {
      this.articles = [];
      this.hasError = false;
      this.errorMessage = '';
      this.loadPopularContent();
    }
  }

  handleSourceFilterChange(event) {
    this.sourceFilter = event.detail.value;
    if (this.searchQuery && this.searchQuery.trim().length > 0) {
      this.currentPage = 1;
      this.performSearch();
    }
  }

  handleSearch() {
    if (!this.searchQuery || this.searchQuery.trim().length === 0) {
      this.showToast('Error', 'Please enter a search query', 'error');
      return;
    }
    this.currentPage = 1;
    this.performSearch();
  }

  handleKeyPress(event) {
    if (event.key === 'Enter') {
      this.handleSearch();
    }
  }

  connectedCallback() {
    // Load popular articles and categories when component loads (no search query)
    this.loadPopularContent();
  }

  async loadPopularContent() {
    // Only load if no search query
    if (!this.searchQuery || this.searchQuery.trim().length === 0) {
      this.isLoadingPopular = true;
      try {
        // Load popular articles and categories in parallel
        const [popularArticlesResult, categoriesResult] = await Promise.all([
          getPopularArticles({ maxResults: 10 }),
          getCategories()
        ]);
        this.popularArticles = popularArticlesResult || [];
        this.categories = categoriesResult || [];
        // Format dates for popular articles
        this.popularArticles = this.formatArticleDates(this.popularArticles);
      } catch (error) {
        console.error('Error loading popular content:', error);
        // Don't show error to user - just log it
      } finally {
        this.isLoadingPopular = false;
      }
    }
  }

  async performSearch() {
    this.isLoading = true;
    this.hasError = false;
    this.errorMessage = '';
    // Clear popular articles and categories when searching
    this.popularArticles = [];
    this.categories = [];

    try {
      const request = {
        searchQuery: this.searchQuery.trim(),
        sourceFilter: this.sourceFilter,
        tagFilters: this.selectedTags,
        categoryFilters: this.selectedCategories,
        dateFrom: this.dateFrom,
        dateTo: this.dateTo,
        maxResults: 25,
        pageNumber: this.currentPage
      };

      const response = await searchArticles({ request: request });

      if (response.hasError) {
        this.hasError = true;
        this.errorMessage = response.errorMessage || 'An error occurred during search';
        this.articles = [];
        this.showToast('Error', this.errorMessage, 'error');
      } else {
        this.articles = response.articles || [];
        // Format dates for display
        this.articles = this.formatArticleDates(this.articles);
        this.totalCount = response.totalCount || 0;
        this.currentPage = response.pageNumber || 1;
        this.totalPages = response.totalPages || 1;
        this.hasMore = response.hasMore || false;

        // Extract available tags and categories from results
        this.updateAvailableFilters();
      }
    } catch (error) {
      this.hasError = true;
      // Try multiple ways to extract error message
      let errorMsg = 'An unexpected error occurred';
      if (error.body) {
        errorMsg = error.body.message || error.body.exceptionType || errorMsg;
      } else if (error.message) {
        errorMsg = error.message;
      } else if (error.toString && error.toString() !== '[object Object]') {
        errorMsg = error.toString();
      }
      
      // If we still have a generic error, provide helpful guidance
      if (errorMsg.includes('Script-thrown') || errorMsg === 'An unexpected error occurred') {
        errorMsg = 'Error connecting to Helpjuice API. Please check: 1) Custom Metadata is configured with your actual API key and Base URL, 2) Remote Site Settings are configured for your Helpjuice domain.';
      }
      
      this.errorMessage = errorMsg;
      this.articles = [];
      this.showToast('Error', this.errorMessage, 'error');
      console.error('Search error:', error);
    } finally {
      this.isLoading = false;
    }
  }

  updateAvailableFilters() {
    const tagsSet = new Set();
    const categoriesSet = new Set();

    this.articles.forEach((article) => {
      if (article.tags) {
        article.tags.forEach((tag) => tagsSet.add(tag));
      }
      if (article.categories) {
        article.categories.forEach((cat) => categoriesSet.add(cat));
      }
    });

    // Convert to format expected by lightning-dual-listbox
    this.availableTags = Array.from(tagsSet)
      .sort()
      .map((tag) => ({ label: tag, value: tag }));
    this.availableCategories = Array.from(categoriesSet)
      .sort()
      .map((cat) => ({ label: cat, value: cat }));
  }

  handleTagFilterChange(event) {
    this.selectedTags = event.detail.value || [];
    if (this.searchQuery) {
      this.currentPage = 1;
      this.performSearch();
    }
  }

  handleCategoryFilterChange(event) {
    this.selectedCategories = event.detail.value || [];
    if (this.searchQuery) {
      this.currentPage = 1;
      this.performSearch();
    }
  }

  handleDateFromChange(event) {
    this.dateFrom = event.detail.value;
    if (this.searchQuery) {
      this.currentPage = 1;
      this.performSearch();
    }
  }

  handleDateToChange(event) {
    this.dateTo = event.detail.value;
    if (this.searchQuery) {
      this.currentPage = 1;
      this.performSearch();
    }
  }

  handleClearFilters() {
    this.selectedTags = [];
    this.selectedCategories = [];
    this.dateFrom = null;
    this.dateTo = null;
    if (this.searchQuery) {
      this.currentPage = 1;
      this.performSearch();
    }
  }

  async handleViewArticle(event) {
    const articleId = event.currentTarget.dataset.id;
    const source = event.currentTarget.dataset.source;
    
    // Try to find in search results first
    let article = this.articles.find(
      (a) => a.id === articleId && a.source === source
    );
    // If not found, try popular articles
    if (!article) {
      article = this.popularArticles.find(
        (a) => a.id === articleId && a.source === source
      );
    }
    
    if (!article) {
      this.showToast('Error', 'Article not found', 'error');
      return;
    }

    // For Helpjuice articles, always fetch full content from API
    // Search results only return truncated previews (answer_sample/long_answer_sample)
    // We need to fetch the full article to get the complete HTML content with images
    if (article.source === 'Helpjuice') {
      this.isLoadingArticle = true;
      this.selectedArticle = article; // Show preview first
      this.showArticleModal = true;
      
      try {
        // Fetch full article details from Helpjuice API
        // This will return the complete HTML content with processed_body (includes images and formatting)
        const fullArticle = await getArticle({ 
          articleId: articleId, 
          source: source 
        });
        
        if (fullArticle) {
          // Format dates for the full article
          if (fullArticle.publishedDate || fullArticle.lastModifiedDate) {
            const formattedArticles = this.formatArticleDates([fullArticle]);
            this.selectedArticle = formattedArticles[0];
          } else {
            this.selectedArticle = fullArticle;
          }
          // Add badge class for styling
          if (fullArticle.source) {
            this.selectedArticle.badgeClass = fullArticle.source === 'Helpjuice' 
              ? 'slds-badge_inverse' 
              : '';
          }
          
          // Check if we have content - if not, show warning
          if (!fullArticle.content || fullArticle.content.trim().length === 0) {
            console.warn('Full article retrieved but content is empty. Article:', fullArticle);
            // Try to use snippet as fallback if content is empty
            if (fullArticle.snippet && fullArticle.snippet.trim().length > 0) {
              this.selectedArticle.content = fullArticle.snippet;
              this.showToast('Warning', 'Full article content not available. Showing preview.', 'warning');
            } else {
              this.showToast('Warning', 'Article content is empty. Please use "Open Externally" to view the article.', 'warning');
            }
          }
        } else {
          // If fetch failed, show error but keep preview
          console.warn('getArticle returned null. Article ID:', articleId, 'Source:', source);
          this.showToast('Warning', 'Could not load full article content. Please use "Open Externally" to view the article.', 'warning');
        }
      } catch (error) {
        console.error('Error fetching article:', error);
        // Extract error message
        let errorMsg = 'Failed to load full article content';
        if (error.body && error.body.message) {
          errorMsg = error.body.message;
        } else if (error.body && typeof error.body === 'string') {
          errorMsg = error.body;
        } else if (error.message) {
          errorMsg = error.message;
        }
        // Show error but keep preview visible
        this.showToast('Error', errorMsg + ' Please use "Open Externally" to view the article.', 'error');
      } finally {
        this.isLoadingArticle = false;
      }
    } else {
      // Salesforce articles already have full content from search
      this.selectedArticle = article;
      this.showArticleModal = true;
    }
  }

  handleCategoryClick(event) {
    const categoryId = event.currentTarget.dataset.categoryId;
    // Set search query to category name and perform search
    const category = this.categories.find((c) => c.id === categoryId);
    if (category) {
      this.searchQuery = category.name;
      this.currentPage = 1;
      this.performSearch();
    }
  }

  async handleCopyLink(event) {
    const url = event.currentTarget.dataset.url;
    if (!url) {
      this.showToast('Error', 'No URL to copy', 'error');
      return;
    }

    try {
      // Use the Clipboard API to copy the URL
      await navigator.clipboard.writeText(url);
      this.showToast('Success', 'Link copied to clipboard', 'success');
    } catch (error) {
      // Fallback for browsers that don't support Clipboard API
      console.error('Error copying to clipboard:', error);
      
      // Fallback: Create a temporary textarea element
      const textarea = document.createElement('textarea');
      textarea.value = url;
      textarea.style.position = 'fixed';
      textarea.style.left = '-999999px';
      document.body.appendChild(textarea);
      textarea.select();
      
      try {
        document.execCommand('copy');
        document.body.removeChild(textarea);
        this.showToast('Success', 'Link copied to clipboard', 'success');
      } catch (fallbackError) {
        document.body.removeChild(textarea);
        console.error('Fallback copy failed:', fallbackError);
        this.showToast('Error', 'Failed to copy link. Please copy manually.', 'error');
      }
    }
  }

  handleCloseModal() {
    this.showArticleModal = false;
    this.selectedArticle = null;
  }

  handlePreviousPage() {
    if (this.canGoPrevious) {
      this.currentPage--;
      this.performSearch();
      this.scrollToTop();
    }
  }

  handleNextPage() {
    if (this.canGoNext) {
      this.currentPage++;
      this.performSearch();
      this.scrollToTop();
    }
  }

  scrollToTop() {
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }

  showToast(title, message, variant) {
    const evt = new ShowToastEvent({
      title: title,
      message: message,
      variant: variant
    });
    this.dispatchEvent(evt);
  }

  formatDate(dateValue) {
    if (!dateValue) return '';
    const date = new Date(dateValue);
    return date.toLocaleDateString();
  }

  formatArticleDates(articles) {
    return articles.map((article) => {
      return {
        ...article,
        formattedLastModifiedDate: this.formatDate(article.lastModifiedDate),
        formattedPublishedDate: this.formatDate(article.publishedDate),
        badgeClass: article.source === 'Helpjuice' ? 'slds-badge_inverse' : ''
      };
    });
  }
}

