function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

const ToastHook = {
  mounted() {
    window.__toastHook = this;
    this.toasts = [];
    this.maxVisible = 3;
    this.autoDismissMs = 5000;
    this.timeouts = {};
  },

  destroyed() {
    Object.values(this.timeouts).forEach(clearTimeout);
    this.timeouts = {};
  },

  addToast(id, status, title, body) {
    const toast = { id, status, title, body };
    this.toasts.unshift(toast);
    this.render();
    this.scheduleDismiss(id);
  },

  render() {
    const container = this.el;
    const toasts = this.toasts.slice(0, this.maxVisible);

    container.innerHTML = toasts.map(toast => `
      <div id="toast-${toast.id}" class="toast-item" data-status="${toast.status}">
        <div class="toast-icon">
          <svg class="notification-status-icon" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" width="16" height="16">
            <path fill="${this.getStatusColor(toast.status)}" d="${this.getStatusPath(toast.status)}" />
          </svg>
        </div>
        <div class="toast-content">
          <p class="toast-title">${escapeHtml(toast.title)}</p>
          ${toast.body ? `<p class="toast-body">${escapeHtml(toast.body)}</p>` : ''}
        </div>
        <button class="toast-close" aria-label="Fechar" onclick="window.__toastHook.removeToast('${toast.id}')">
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32" width="16" height="16">
            <path fill="currentColor" d="M24 9.4L22.6 8 16 14.6 9.4 8 8 9.4l6.6 6.6L8 22.6 9.4 24l6.6-6.6 6.6 6.6 1.4-1.4-6.6-6.6z" />
          </svg>
        </button>
      </div>
    `).join('');
  },

  removeToast(id) {
    if (this.timeouts[id]) {
      clearTimeout(this.timeouts[id]);
      delete this.timeouts[id];
    }
    const element = document.getElementById(`toast-${id}`);
    if (element) {
      element.classList.add('toast-exit');
      setTimeout(() => {
        this.toasts = this.toasts.filter(t => t.id !== id);
        this.render();
      }, 200);
    }
  },

  scheduleDismiss(id) {
    this.timeouts[id] = setTimeout(() => this.removeToast(id), this.autoDismissMs);
  },

  getStatusColor(status) {
    const colors = {
      info: '#0f62fe',
      success: '#24a148',
      warning: '#f1c21b',
      error: '#da1e28'
    };
    return colors[status] || colors.info;
  },

  getStatusPath(status) {
    const paths = {
      info: 'M11 15h2v2h-2zm0-8h2v6h-2zm.93-6.37l-1.42.5A9.966 9.966 0 0 0 8 2a10 10 0 0 0-10 10 10 10 0 0 0 10 10 10 10 0 0 0 9.93-8.63l-1.42-.5A8 8 0 1 1 8 0a8 8 0 0 1 7.93 6.63z',
      success: 'M16 48a48 48 0 1 1 48-48 48 48 0 0 1-48 48zm21.89-76.29l-21-21a1.47 1.47 0 0 0-2.08 0l-25 25a1.42 1.42 0 0 0 0 2l21 21a1.47 1.47 0 0 0 2.08 0l25-25a1.42 1.42 0 0 0 0-2z',
      warning: 'M46.07 34.51l-19-28A2 2 0 0 0 25.39 5h-.78a2 2 0 0 0-1.68.92l-19 28A2 2 0 0 0 4.61 37h38.78a2 2 0 0 0 1.68-2.49zM24 30a2 2 0 0 1-2-2v-4a2 2 0 0 1 4 0v4a2 2 0 0 1-2 2zm4 12a2 2 0 0 1-2 2h-4a2 2 0 0 1 0-4h4a2 2 0 0 1 2 2z',
      error: 'M34.5 30.3L13.9 5.9a1.5 1.5 0 0 0-2.6 0L.5 30.3a1.5 1.5 0 0 0 1.3 2.2h39.4a1.5 1.5 0 0 0 1.3-2.2zM23 36a2 2 0 1 1 2-2 2 2 0 0 1-2 2zm4-12a2 2 0 0 1-4 0V16a2 2 0 0 1 4 0z'
    };
    return paths[status] || paths.info;
  }
};

export default ToastHook;
