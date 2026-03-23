const express = require('express');

const { asyncHandler } = require('../lib/async-handler');
const { success } = require('../lib/http');
const { badRequest } = require('../lib/errors');
const { buildUploadCapabilities, storeUploadedAsset } = require('../services/storage-service');

const allowedCategories = new Set([
  'profile_image',
  'kyc_front',
  'kyc_back',
  'kyc_portrait',
  'kyc_liveness_video',
  'property_image',
  'property_document',
  'transaction_document',
  'misc',
]);

function buildUploadsRouter() {
  const router = express.Router();

  router.get('/capabilities', asyncHandler(async (req, res) => {
    return success(res, buildUploadCapabilities(Array.from(allowedCategories)));
  }));

  router.post('/', asyncHandler(async (req, res) => {
    const {
      category = 'misc',
      file_name,
      mime_type,
      base64_data,
      expected_checksum,
    } = req.body ?? {};

    if (!file_name || !mime_type || !base64_data) {
      throw badRequest('category, file_name, mime_type, and base64_data are required.');
    }

    if (!allowedCategories.has(String(category).trim().toLowerCase())) {
      throw badRequest('Unsupported upload category.');
    }

    const asset = await storeUploadedAsset({
      ownerUserId: req.auth.uid,
      category,
      fileName: file_name,
      mimeType: mime_type,
      base64Data: base64_data,
      req,
      expectedChecksum: expected_checksum ?? null,
    });

    return success(res, asset, undefined, 201);
  }));

  return router;
}

module.exports = { buildUploadsRouter };
