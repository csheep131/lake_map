// === WAMMSSEE LAKE MAPPER — INTERACTIVE WEBSITE ===

// --- Deep Sea Particle Canvas ---
(function() {
  const canvas = document.getElementById('deepSea');
  if (!canvas) return;
  
  const ctx = canvas.getContext('2d');
  let width, height;
  let particles = [];
  let bubbles = [];
  
  function resize() {
    width = canvas.width = window.innerWidth;
    height = canvas.height = window.innerHeight;
  }
  
  window.addEventListener('resize', resize);
  resize();
  
  class Particle {
    constructor() {
      this.reset();
    }
    
    reset() {
      this.x = Math.random() * width;
      this.y = Math.random() * height;
      this.size = Math.random() * 2 + 0.5;
      this.speedY = Math.random() * 0.3 + 0.1;
      this.speedX = (Math.random() - 0.5) * 0.2;
      this.opacity = Math.random() * 0.4 + 0.1;
      this.hue = Math.random() > 0.7 ? 170 : 200; // cyan vs steel-blue
    }
    
    update() {
      this.y -= this.speedY;
      this.x += this.speedX;
      
      if (this.y < -10) {
        this.y = height + 10;
        this.x = Math.random() * width;
      }
    }
    
    draw() {
      ctx.beginPath();
      ctx.arc(this.x, this.y, this.size, 0, Math.PI * 2);
      ctx.fillStyle = `hsla(${this.hue}, 80%, 60%, ${this.opacity})`;
      ctx.fill();
    }
  }
  
  class Bubble {
    constructor() {
      this.reset();
    }
    
    reset() {
      this.x = Math.random() * width;
      this.y = height + Math.random() * 100;
      this.size = Math.random() * 4 + 1;
      this.speed = Math.random() * 0.8 + 0.3;
      this.wobble = Math.random() * Math.PI * 2;
      this.wobbleSpeed = Math.random() * 0.02 + 0.01;
      this.opacity = Math.random() * 0.15 + 0.05;
    }
    
    update() {
      this.y -= this.speed;
      this.wobble += this.wobbleSpeed;
      this.x += Math.sin(this.wobble) * 0.3;
      
      if (this.y < -20) {
        this.reset();
      }
    }
    
    draw() {
      ctx.beginPath();
      ctx.arc(this.x, this.y, this.size, 0, Math.PI * 2);
      ctx.strokeStyle = `rgba(0, 229, 204, ${this.opacity})`;
      ctx.lineWidth = 0.8;
      ctx.stroke();
    }
  }
  
  // Initialize
  for (let i = 0; i < 80; i++) {
    particles.push(new Particle());
  }
  for (let i = 0; i < 25; i++) {
    bubbles.push(new Bubble());
  }
  
  function animate() {
    ctx.clearRect(0, 0, width, height);
    
    // Draw gradient background
    const gradient = ctx.createLinearGradient(0, 0, 0, height);
    gradient.addColorStop(0, '#050F1A');
    gradient.addColorStop(0.5, '#081520');
    gradient.addColorStop(1, '#0A1929');
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, width, height);
    
    particles.forEach(p => {
      p.update();
      p.draw();
    });
    
    bubbles.forEach(b => {
      b.update();
      b.draw();
    });
    
    requestAnimationFrame(animate);
  }
  
  animate();
})();

// --- Gallery Screen Switcher ---
(function() {
  const screen = document.getElementById('galleryScreen');
  const buttons = document.querySelectorAll('.gallery-btn');
  
  if (!screen || buttons.length === 0) return;
  
  buttons.forEach(btn => {
    btn.addEventListener('click', () => {
      buttons.forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      
      const newSrc = btn.dataset.screen;
      screen.style.opacity = '0';
      screen.style.transform = 'scale(0.95)';
      
      setTimeout(() => {
        screen.src = newSrc;
        screen.onload = () => {
          screen.style.opacity = '1';
          screen.style.transform = 'scale(1)';
        };
      }, 250);
    });
  });
  
  screen.style.transition = 'opacity 0.3s ease, transform 0.3s ease';
})();

// --- Animated Counter ---
(function() {
  const depthEl = document.getElementById('statDepths');
  if (!depthEl) return;
  
  let counted = false;
  
  function countUp(el, target, duration = 2000) {
    const start = performance.now();
    
    function update(now) {
      const elapsed = now - start;
      const progress = Math.min(elapsed / duration, 1);
      const ease = 1 - Math.pow(1 - progress, 3); // ease-out cubic
      el.textContent = Math.floor(ease * target);
      
      if (progress < 1) {
        requestAnimationFrame(update);
      }
    }
    
    requestAnimationFrame(update);
  }
  
  const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting && !counted) {
        counted = true;
        countUp(depthEl, 42, 2500);
      }
    });
  }, { threshold: 0.5 });
  
  observer.observe(depthEl);
})();

// --- Scroll Reveal ---
(function() {
  const observerOptions = {
    root: null,
    rootMargin: '0px',
    threshold: 0.1
  };
  
  const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('revealed');
        observer.unobserve(entry.target);
      }
    });
  }, observerOptions);
  
  document.querySelectorAll('.feature-card, .guide-step, .stat-item').forEach(el => {
    el.style.opacity = '0';
    el.style.transform = 'translateY(24px)';
    el.style.transition = 'opacity 0.6s ease, transform 0.6s ease';
    observer.observe(el);
  });
  
  // Add reveal CSS class
  const style = document.createElement('style');
  style.textContent = `
    .revealed {
      opacity: 1 !important;
      transform: translateY(0) !important;
    }
  `;
  document.head.appendChild(style);
})();

// --- Nav scroll effect ---
(function() {
  const nav = document.querySelector('.nav-glass');
  if (!nav) return;
  
  let lastScroll = 0;
  
  window.addEventListener('scroll', () => {
    const currentScroll = window.pageYOffset;
    
    if (currentScroll > 50) {
      nav.style.background = 'rgba(5, 15, 26, 0.95)';
      nav.style.borderBottomColor = 'rgba(0, 229, 204, 0.2)';
    } else {
      nav.style.background = 'linear-gradient(180deg, rgba(5,15,26,0.95) 0%, rgba(5,15,26,0.7) 60%, transparent 100%)';
      nav.style.borderBottomColor = 'rgba(0, 229, 204, 0.15)';
    }
    
    lastScroll = currentScroll;
  });
})();

// --- Smooth scroll for anchor links ---
document.querySelectorAll('a[href^="#"]').forEach(anchor => {
  anchor.addEventListener('click', function(e) {
    e.preventDefault();
    const target = document.querySelector(this.getAttribute('href'));
    if (target) {
      target.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }
  });
});

console.log('⚓ Wammsee Lake Mapper — Website loaded');
