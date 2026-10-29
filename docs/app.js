document.addEventListener('DOMContentLoaded', () => {
  const isEnglish = document.documentElement.lang === 'en';

  // Gallery Tabs Switching
  const tabBtns = document.querySelectorAll('.tab-btn');
  const slides = document.querySelectorAll('.gallery-slide');

  tabBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      const targetId = btn.getAttribute('data-target');

      tabBtns.forEach(b => b.classList.remove('active'));
      slides.forEach(s => s.classList.remove('active'));

      btn.classList.add('active');
      const activeSlide = document.getElementById(targetId);
      if (activeSlide) {
        activeSlide.classList.add('active');
      }
    });
  });

  // Copy PromptPay Number
  const copyPromptPayBtn = document.getElementById('copyPromptPayBtn');
  if (copyPromptPayBtn) {
    copyPromptPayBtn.addEventListener('click', () => {
      const number = copyPromptPayBtn.getAttribute('data-clipboard-text') || '0959201930';
      const msg = isEnglish 
        ? 'PromptPay number 095-920-1930 copied to clipboard!' 
        : 'คัดลอกหมายเลขพร้อมเพย์ 095-920-1930 แล้ว!';
      copyToClipboard(number, msg);
    });
  }

  // Copy Terminal Commands
  const copyCmdBtns = document.querySelectorAll('.btn-copy');
  copyCmdBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      const textToCopy = btn.getAttribute('data-copy');
      if (textToCopy) {
        const msg = isEnglish ? 'Command copied to clipboard!' : 'คัดลอกคำสั่งไปยัง Clipboard แล้ว!';
        copyToClipboard(textToCopy, msg);
        const origText = btn.textContent;
        btn.textContent = isEnglish ? 'Copied ✓' : 'คัดลอกแล้ว ✓';
        setTimeout(() => {
          btn.textContent = origText;
        }, 2000);
      }
    });
  });
});

// Toast Helper
function showToast(message) {
  let toast = document.getElementById('toastNotification');
  if (!toast) {
    toast = document.createElement('div');
    toast.id = 'toastNotification';
    toast.className = 'toast';
    document.body.appendChild(toast);
  }
  toast.innerHTML = `<span>✓</span> <span>${message}</span>`;
  toast.classList.add('show');

  setTimeout(() => {
    toast.classList.remove('show');
  }, 3000);
}

// Copy to Clipboard Utility
function copyToClipboard(text, successMsg) {
  if (navigator.clipboard && window.isSecureContext) {
    navigator.clipboard.writeText(text).then(() => {
      showToast(successMsg);
    }).catch(() => {
      fallbackCopy(text, successMsg);
    });
  } else {
    fallbackCopy(text, successMsg);
  }
}

function fallbackCopy(text, successMsg) {
  const textArea = document.createElement('textarea');
  textArea.value = text;
  textArea.style.position = 'fixed';
  textArea.style.opacity = '0';
  document.body.appendChild(textArea);
  textArea.focus();
  textArea.select();
  try {
    document.execCommand('copy');
    showToast(successMsg);
  } catch (err) {
    alert((document.documentElement.lang === 'en' ? 'Copy failed: ' : 'คัดลอกไม่สำเร็จ: ') + text);
  }
  document.body.removeChild(textArea);
}
