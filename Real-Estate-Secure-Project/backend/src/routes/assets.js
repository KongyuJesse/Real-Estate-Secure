const express = require('express');

const { asyncHandler } = require('../lib/async-handler');
const { success } = require('../lib/http');
const { forbidden, notFound } = require('../lib/errors');
const { isAdmin } = require('../services/authorization-service');
const {
  createAssetAccessUrl,
  getAssetRecord,
  streamAssetToResponse,
  verifyAssetSignature,
} = require('../services/storage-service');

function buildAssetsRouter({ requireAuth }) {
  const router = express.Router();

  router.get('/:id/access', requireAuth, asyncHandler(async (req, res) => {
    const asset = await getAssetRecord(req.params.id);
    if (!asset) {
      throw notFound('Asset not found.');
    }
    if (!isAdmin(req) && String(asset.owner_user_id || '') !== String(req.auth.uid)) {
      throw forbidden('You do not have access to this asset.');
    }
    const access = await createAssetAccessUrl(asset.uuid, req);
    return success(res, {
      id: asset.uuid,
      url: access.url,
      visibility: asset.visibility,
      mime_type: asset.mime_type,
    });
  }));

  router.get('/:id/content', asyncHandler(async (req, res) => {
    const asset = await getAssetRecord(req.params.id);
    if (!asset) {
      throw notFound('Asset not found.');
    }

    const expires = Number(req.query.expires ?? 0);
    const signature = String(req.query.signature || '');
    if (!Number.isFinite(expires) || expires < Date.now()) {
      throw forbidden('Asset link has expired.');
    }
    if (!signature || !verifyAssetSignature(asset.uuid, String(expires), signature)) {
      throw forbidden('Asset signature is invalid.');
    }

    await streamAssetToResponse(asset, res);
  }));

  return router;
}

module.exports = { buildAssetsRouter };
