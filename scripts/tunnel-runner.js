const { spawn } = require('child_process');

const SUBDOMAIN = process.env.LT_SUBDOMAIN || 'whatsappia24rhuan';

function startTunnel() {
  console.log(`[tunnel] starting localtunnel on port 3000 with subdomain: ${SUBDOMAIN}`);
  const child = spawn('npx', ['localtunnel', '--port', '3000', '--subdomain', SUBDOMAIN], {
    shell: true,
    stdio: 'inherit',
  });

  child.on('exit', (code) => {
    console.log(`[tunnel] exited with code ${code}. restarting in 5s...`);
    setTimeout(startTunnel, 5000);
  });

  child.on('error', (err) => {
    console.error('[tunnel] process error:', err.message);
    setTimeout(startTunnel, 5000);
  });
}

startTunnel();
