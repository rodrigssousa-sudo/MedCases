'use strict';
const crypto = require('node:crypto');
const {S3Client, PutObjectCommand, GetObjectCommand, DeleteObjectCommand} = require('@aws-sdk/client-s3');

function createTranscriptionTempStorage(env = process.env) {
  const bucket = env.TRANSCRIPTION_TEMP_BUCKET;
  const region = env.TRANSCRIPTION_TEMP_REGION;
  const prefix = env.TRANSCRIPTION_TEMP_PREFIX || 'transcription/';
  if (!bucket || !region) return null;
  if (!/^[a-zA-Z0-9/_-]+\/$/.test(prefix)) throw Error('TRANSCRIPTION_PREFIX_INVALID');
  if (bucket === env.MEDCASES_CLINICAL_CONTENT_S3_BUCKET) throw Error('TRANSCRIPTION_BUCKET_MUST_BE_DEDICATED');
  const endpoint = env.TRANSCRIPTION_TEMP_ENDPOINT || undefined;
  if (endpoint && !endpoint.startsWith('https://')) throw Error('TRANSCRIPTION_ENDPOINT_REQUIRES_TLS');
  const accessKeyId=env.TRANSCRIPTION_TEMP_ACCESS_KEY_ID;
  const secretAccessKey=env.TRANSCRIPTION_TEMP_SECRET_ACCESS_KEY;
  if (Boolean(accessKeyId)!==Boolean(secretAccessKey)) throw Error('TRANSCRIPTION_CREDENTIALS_INCOMPLETE');
  const client = new S3Client({region, endpoint, maxAttempts: 3,
    ...(accessKeyId?{credentials:{accessKeyId,secretAccessKey}}:{})});
  const valid = key => {
    if (!key.startsWith(prefix) || !/^[a-zA-Z0-9/_-]+$/.test(key)) throw Error('TRANSCRIPTION_OBJECT_BINDING_INVALID');
    return key;
  };
  return {
    key(jobId, index, uploadToken) {
      return `${prefix}${crypto.createHash('sha256').update(jobId).digest('hex')}/${index}/${uploadToken}`;
    },
    async put(key, body, contentLength) {
      await client.send(new PutObjectCommand({Bucket: bucket, Key: valid(key), Body: body,
        ...(contentLength===undefined?{}:{ContentLength:contentLength}),
        ContentType: 'application/octet-stream', ServerSideEncryption: 'AES256'}));
    },
    async getStream(key) {
      const r=await client.send(new GetObjectCommand({Bucket:bucket,Key:valid(key)}));
      return {body:r.Body,contentLength:r.ContentLength};
    },
    async get(key) {
      const r = await client.send(new GetObjectCommand({Bucket: bucket, Key: valid(key)}));
      if (r.ContentLength > 25 * 1024 * 1024) { r.Body.destroy(); throw Error('AUDIO_TYPE_INVALID'); }
      return Buffer.from(await r.Body.transformToByteArray());
    },
    async remove(key) { await client.send(new DeleteObjectCommand({Bucket: bucket, Key: valid(key)})); },
  };
}
module.exports = {createTranscriptionTempStorage};
