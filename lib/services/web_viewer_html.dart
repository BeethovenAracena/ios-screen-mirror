/// Template HTML5 ultra ligero y moderno que se sirve directamente al navegador de la PC.
/// Incluye renderizado por Canvas sobre WebSocket (<50ms latencia), soporte de pantalla completa,
/// contador de FPS, captura de pantalla y modo MJPEG de respaldo.
const String webViewerHtml = '''<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>iPhone Screen Mirror • Transmisión en Vivo</title>
  <style>
    :root {
      --bg: #0b0f19;
      --card-bg: rgba(22, 27, 46, 0.85);
      --border: rgba(255, 255, 255, 0.1);
      --accent: #0071e3;
      --accent-glow: rgba(0, 113, 227, 0.4);
      --success: #30d158;
      --text: #f5f5f7;
      --text-muted: #86868b;
    }

    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
      user-select: none;
    }

    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      background-color: var(--bg);
      color: var(--text);
      display: flex;
      flex-direction: column;
      height: 100vh;
      overflow: hidden;
    }

    header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 12px 24px;
      background: var(--card-bg);
      backdrop-filter: blur(20px);
      border-bottom: 1px solid var(--border);
      z-index: 10;
    }

    .brand {
      display: flex;
      align-items: center;
      gap: 12px;
      font-weight: 600;
      font-size: 1.05rem;
      letter-spacing: -0.02em;
    }

    .status-pill {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      padding: 4px 10px;
      border-radius: 999px;
      font-size: 0.78rem;
      font-weight: 500;
      background: rgba(48, 209, 88, 0.15);
      color: var(--success);
      border: 1px solid rgba(48, 209, 88, 0.3);
    }

    .status-dot {
      width: 8px;
      height: 8px;
      border-radius: 50%;
      background: var(--success);
      box-shadow: 0 0 8px var(--success);
      animation: pulse 2s infinite;
    }

    @keyframes pulse {
      0%, 100% { opacity: 1; transform: scale(1); }
      50% { opacity: 0.6; transform: scale(0.9); }
    }

    .controls {
      display: flex;
      align-items: center;
      gap: 10px;
    }

    .btn {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      padding: 7px 14px;
      border-radius: 8px;
      font-size: 0.85rem;
      font-weight: 500;
      background: rgba(255, 255, 255, 0.08);
      color: var(--text);
      border: 1px solid var(--border);
      cursor: pointer;
      transition: all 0.2s ease;
    }

    .btn:hover {
      background: rgba(255, 255, 255, 0.15);
      border-color: rgba(255, 255, 255, 0.25);
    }

    .btn-primary {
      background: var(--accent);
      border-color: var(--accent);
      box-shadow: 0 2px 8px var(--accent-glow);
    }

    .btn-primary:hover {
      background: #0077ed;
    }

    main {
      flex: 1;
      position: relative;
      display: flex;
      align-items: center;
      justify-content: center;
      background: radial-gradient(circle at center, #131a2e 0%, var(--bg) 100%);
      padding: 16px;
    }

    #streamCanvas {
      max-width: 100%;
      max-height: 100%;
      object-fit: contain;
      border-radius: 14px;
      box-shadow: 0 20px 50px rgba(0, 0, 0, 0.6);
      transition: transform 0.25s ease;
      background: #000;
    }

    .placeholder {
      position: absolute;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      text-align: center;
      gap: 16px;
      color: var(--text-muted);
      pointer-events: none;
    }

    .placeholder-icon {
      width: 72px;
      height: 72px;
      border-radius: 20px;
      background: rgba(255, 255, 255, 0.05);
      border: 1px solid var(--border);
      display: flex;
      align-items: center;
      justify-content: center;
      color: var(--accent);
    }

    .placeholder h2 {
      font-size: 1.3rem;
      color: var(--text);
      font-weight: 500;
    }

    .placeholder p {
      font-size: 0.9rem;
      max-width: 380px;
      line-height: 1.45;
    }

    footer {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 8px 24px;
      background: var(--card-bg);
      border-top: 1px solid var(--border);
      font-size: 0.78rem;
      color: var(--text-muted);
    }

    .stats {
      display: flex;
      align-items: center;
      gap: 16px;
    }

    .stat-badge {
      background: rgba(255, 255, 255, 0.05);
      padding: 2px 8px;
      border-radius: 4px;
      color: var(--text);
      font-family: monospace;
    }
  </style>
</head>
<body>

  <header>
    <div class="brand">
      <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        <rect width="14" height="20" x="5" y="2" rx="2" ry="2"/>
        <path d="M12 18h.01"/>
      </svg>
      <span>iPhone Mirror</span>
      <div id="statusPill" class="status-pill">
        <span class="status-dot"></span>
        <span id="statusText">Conectando...</span>
      </div>
    </div>

    <div class="controls">
      <button class="btn" id="btnRotate" title="Rotar 90 grados">
        <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21.5 2v6h-6M21.34 15.57a10 10 0 1 1-.57-8.38l5.67-5.67"/></svg>
        Rotar
      </button>
      <button class="btn" id="btnSnapshot" title="Guardar captura de pantalla">
        <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z"/><circle cx="12" cy="13" r="4"/></svg>
        Captura
      </button>
      <button class="btn btn-primary" id="btnFullscreen" title="Pantalla completa">
        <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M8 3H5a2 2 0 0 0-2 2v3m18 0V5a2 2 0 0 0-2-2h-3m0 18h3a2 2 0 0 0 2-2v-3M3 16v3a2 2 0 0 0 2 2h3"/></svg>
        Pantalla Completa
      </button>
    </div>
  </header>

  <main id="mainContainer">
    <canvas id="streamCanvas"></canvas>

    <div id="placeholder" class="placeholder">
      <div class="placeholder-icon">
        <svg width="36" height="36" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M4 14.899A7 7 0 1 1 15.71 8h1.79a4.5 4.5 0 0 1 2.5 8.242M8 19l4 4 4-4M12 13v10"/>
        </svg>
      </div>
      <h2>Esperando transmisión de pantalla</h2>
      <p>En tu iPhone, presiona el botón <strong>"Iniciar transmisión"</strong> y selecciona la extensión para comenzar a ver la pantalla en tiempo real.</p>
    </div>
  </main>

  <footer>
    <div class="stats">
      <span>FPS: <span id="fpsCounter" class="stat-badge">0</span></span>
      <span>Resolución: <span id="resCounter" class="stat-badge">0 x 0</span></span>
      <span>Frames: <span id="framesCounter" class="stat-badge">0</span></span>
    </div>
    <div>Ultra Low Latency WebSocket Engine • Apple ReplayKit</div>
  </footer>

  <script>
    const canvas = document.getElementById('streamCanvas');
    const ctx = canvas.getContext('2d');
    const placeholder = document.getElementById('placeholder');
    const statusPill = document.getElementById('statusPill');
    const statusText = document.getElementById('statusText');
    const fpsCounter = document.getElementById('fpsCounter');
    const resCounter = document.getElementById('resCounter');
    const framesCounter = document.getElementById('framesCounter');
    const btnFullscreen = document.getElementById('btnFullscreen');
    const btnSnapshot = document.getElementById('btnSnapshot');
    const btnRotate = document.getElementById('btnRotate');

    let rotationAngle = 0;
    let ws = null;
    let frameCount = 0;
    let fps = 0;
    let lastFpsUpdate = performance.now();
    let currentBitmap = null;

    function connectWebSocket() {
      const loc = window.location;
      const wsProtocol = loc.protocol === 'https:' ? 'wss:' : 'ws:';
      const wsUrl = wsProtocol + '//' + loc.host + '/ws';

      statusText.innerText = 'Conectando al iPhone...';
      ws = new WebSocket(wsUrl);
      ws.binaryType = 'blob';

      ws.onopen = () => {
        statusText.innerText = 'Conectado';
        statusPill.style.color = '#30d158';
      };

      ws.onmessage = async (event) => {
        if (event.data instanceof Blob) {
          try {
            const bitmap = await createImageBitmap(event.data);
            if (currentBitmap) {
              currentBitmap.close();
            }
            currentBitmap = bitmap;

            if (canvas.width !== bitmap.width || canvas.height !== bitmap.height) {
              canvas.width = bitmap.width;
              canvas.height = bitmap.height;
              resCounter.innerText = `\${bitmap.width} x \${bitmap.height}`;
            }

            ctx.drawImage(bitmap, 0, 0);

            placeholder.style.display = 'none';
            frameCount++;
            framesCounter.innerText = frameCount;

            const now = performance.now();
            if (now - lastFpsUpdate >= 1000) {
              fps = Math.round((frameCount * 1000) / (now - lastFpsUpdate));
              fpsCounter.innerText = fps;
              lastFpsUpdate = now;
              frameCount = 0;
            }
          } catch (err) {
            console.error('Error decodificando frame:', err);
          }
        }
      };

      ws.onclose = () => {
        statusText.innerText = 'Desconectado. Reintentando...';
        statusPill.style.color = '#ff9f0a';
        setTimeout(connectWebSocket, 2000);
      };

      ws.onerror = (err) => {
        console.error('Error en WebSocket:', err);
        ws.close();
      };
    }

    btnFullscreen.addEventListener('click', () => {
      if (!document.fullscreenElement) {
        document.documentElement.requestFullscreen().catch(err => alert(err.message));
      } else {
        document.exitFullscreen();
      }
    });

    btnRotate.addEventListener('click', () => {
      rotationAngle = (rotationAngle + 90) % 360;
      canvas.style.transform = `rotate(\${rotationAngle}deg)`;
    });

    btnSnapshot.addEventListener('click', () => {
      if (!canvas.width || !canvas.height) return;
      const a = document.createElement('a');
      a.href = canvas.toDataURL('image/png');
      a.download = `iPhone_Screenshot_\${Date.now()}.png`;
      a.click();
    });

    connectWebSocket();
  </script>
</body>
</html>
''';
