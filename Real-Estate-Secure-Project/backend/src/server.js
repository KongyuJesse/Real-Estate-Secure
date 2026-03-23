const http = require('http');
const net = require('net');

const { app } = require('./app');
const { config } = require('./config');
const { query, closePools } = require('./db');
const { runMigrations } = require('./lib/migrations');
const { connectRedis } = require('./services/redis-service');

let activeServer;
let shuttingDown = false;

function logInfo(message) {
  console.log(`${new Date().toISOString()} INFO ${message}`);
}

function logError(message) {
  console.error(`${new Date().toISOString()} ERROR ${message}`);
}

async function shutdownWithError(error, { withStack = true } = {}) {
  if (withStack) {
    console.error(error);
  } else {
    logError(error.message);
  }
  await closePools().catch(() => {});
  process.exit(1);
}

async function shutdownGracefully(signal) {
  if (shuttingDown) {
    return;
  }
  shuttingDown = true;
  logInfo(`Received ${signal}; shutting down gracefully.`);

  await new Promise((resolve) => {
    if (!activeServer) {
      resolve();
      return;
    }
    activeServer.close(() => resolve());
    setTimeout(resolve, 10000).unref();
  });

  await closePools().catch(() => {});
  process.exit(0);
}

function checkPortAvailability(port, host = '0.0.0.0') {
  return new Promise((resolve, reject) => {
    const server = net.createServer();

    server.once('error', (error) => {
      if (error.code === 'EADDRINUSE') {
        resolve(false);
        return;
      }

      reject(error);
    });

    server.once('listening', () => {
      server.close((closeError) => {
        if (closeError) {
          reject(closeError);
          return;
        }
        resolve(true);
      });
    });

    server.listen(port, host);
  });
}

function probeExistingBackend(port) {
  return new Promise((resolve) => {
    const request = http.request(
      {
        host: '127.0.0.1',
        port,
        path: '/health',
        method: 'GET',
        timeout: 1500,
      },
      (response) => {
        let body = '';
        response.setEncoding('utf8');
        response.on('data', (chunk) => {
          body += chunk;
        });
        response.on('end', () => {
          try {
            const parsed = JSON.parse(body);
            const service = parsed?.data?.service;
            resolve({
              ok:
                response.statusCode === 200 &&
                service === 'real-estate-secure-backend',
              statusCode: response.statusCode,
              service,
            });
          } catch (error) {
            resolve({ ok: false, statusCode: response.statusCode });
          }
        });
      },
    );

    request.on('timeout', () => {
      request.destroy();
      resolve({ ok: false, timeout: true });
    });

    request.on('error', () => resolve({ ok: false }));
    request.end();
  });
}

async function start() {
  const portAvailable = await checkPortAvailability(config.port);
  if (!portAvailable) {
    const probe = await probeExistingBackend(config.port);
    if (probe.ok) {
      logInfo(
        `Backend already running on http://127.0.0.1:${config.port}; reusing existing instance.`,
      );
      await closePools().catch(() => {});
      process.exit(0);
    }

    await shutdownWithError(
      new Error(
        [
          `Port ${config.port} is already in use.`,
          'Another process is listening on that port.',
          'Stop that process or start this backend on a different port.',
          'Windows examples:',
          `  netstat -ano | findstr :${config.port}`,
          '  taskkill /PID <pid> /F',
          `  $env:PORT=${config.port + 1}; npm start`,
        ].join('\n'),
      ),
      { withStack: false },
    );
    return;
  }

  if (config.autoRunMigrations) {
    await runMigrations({ withSeeds: config.autoRunSeeds, logger: console });
  } else {
    await query('SELECT 1');
  }

  await connectRedis().catch(() => null);

  const server = app.listen(config.port, '0.0.0.0');
  activeServer = server;

  server.on('listening', () => {
    logInfo(`Server listening on http://0.0.0.0:${config.port} env=${config.env}`);
  });

  server.on('error', async (error) => {
    if (error.code === 'EADDRINUSE') {
      await shutdownWithError(
        new Error(
          [
            `Port ${config.port} is already in use.`,
            'Another backend instance may already be running.',
            'Use the existing server, stop the process using that port, or start this instance on another port.',
            'Windows examples:',
            `  netstat -ano | findstr :${config.port}`,
            '  taskkill /PID <pid> /F',
            `  $env:PORT=${config.port + 1}; npm start`,
          ].join('\n'),
        ),
        { withStack: false },
      );
      return;
    }

    await shutdownWithError(error);
  });
}

process.on('SIGINT', () => {
  void shutdownGracefully('SIGINT');
});

process.on('SIGTERM', () => {
  void shutdownGracefully('SIGTERM');
});

start().catch(async (error) => {
  logError('Server startup failed');
  await shutdownWithError(error);
});
