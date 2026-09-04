'use strict';

const CLOUD_RESOURCE_MANAGER_V3 = 'https://cloudresourcemanager.googleapis.com/v3';
const CLOUD_RESOURCE_MANAGER_V1 = 'https://cloudresourcemanager.googleapis.com/v1';
const SERVICE_USAGE_V1 = 'https://serviceusage.googleapis.com/v1';
const GENERATIVE_LANGUAGE_V1 = 'https://generativelanguage.googleapis.com/v1';
const GEMINI_SERVICE = 'generativelanguage.googleapis.com';
const REQUIRED_QUOTA_PERMISSION = 'serviceusage.services.use';

function requireNonEmptyString(value, name) {
  if (typeof value !== 'string' || value.trim() === '') {
    throw new TypeError(`${name}_REQUIRED`);
  }
  return value;
}

function assertProjectId(projectId) {
  const value = requireNonEmptyString(projectId, 'PROJECT_ID');
  if (!/^[a-z][a-z0-9-]{4,28}[a-z0-9]$/.test(value)) {
    throw new Error('PROJECT_ID_FORMAT_INVALID');
  }
  return value;
}

function projectNumberFromName(name) {
  const match = /^projects\/(\d+)$/.exec(String(name || ''));
  return match ? match[1] : null;
}

class StudyGoogleAiOAuthProjectDiscoveryValidationV1 {
  constructor({ authorizedFetch, clock }) {
    if (typeof authorizedFetch !== 'function') {
      throw new TypeError('AUTHORIZED_FETCH_REQUIRED');
    }
    this.authorizedFetch = authorizedFetch;
    this.clock = typeof clock === 'function' ? clock : Date.now;
  }

  async requestJson(url, { accessToken, method, headers, body }) {
    const token = requireNonEmptyString(accessToken, 'ACCESS_TOKEN');
    const response = await this.authorizedFetch(url, {
      method: method || 'GET',
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: 'application/json',
        ...(body ? { 'Content-Type': 'application/json' } : {}),
        ...(headers || {}),
      },
      ...(body ? { body: JSON.stringify(body) } : {}),
    });
    if (!response || typeof response.status !== 'number') {
      throw new Error('GOOGLE_API_RESPONSE_INVALID');
    }
    if (response.status < 200 || response.status >= 300) {
      throw new Error(`GOOGLE_API_HTTP_${response.status}`);
    }
    if (typeof response.json !== 'function') {
      throw new Error('GOOGLE_API_JSON_RESPONSE_REQUIRED');
    }
    return response.json();
  }

  async discoverProjects({ accessToken, maxPages }) {
    const limit = Math.max(1, Math.min(Number(maxPages || 5), 10));
    const found = [];
    let pageToken = '';
    for (let page = 0; page < limit; page += 1) {
      const params = new URLSearchParams({ query: 'state:ACTIVE', pageSize: '100' });
      if (pageToken) params.set('pageToken', pageToken);
      const data = await this.requestJson(`${CLOUD_RESOURCE_MANAGER_V3}/projects:search?${params.toString()}`, { accessToken });
      const projects = Array.isArray(data.projects) ? data.projects : [];
      projects.forEach((project) => {
        if (project && project.state === 'ACTIVE' && project.projectId) {
          found.push({
            projectId: project.projectId,
            projectNumber: projectNumberFromName(project.name),
            displayName: project.displayName || null,
            state: project.state,
          });
        }
      });
      pageToken = typeof data.nextPageToken === 'string' ? data.nextPageToken : '';
      if (!pageToken) break;
    }
    return found;
  }

  async validateProject({ accessToken, projectId }) {
    const requestedProjectId = assertProjectId(projectId);

    const project = await this.requestJson(
      `${CLOUD_RESOURCE_MANAGER_V3}/projects/${encodeURIComponent(requestedProjectId)}`,
      { accessToken },
    );
    if (!project || project.projectId !== requestedProjectId || project.state !== 'ACTIVE') {
      throw new Error('PROJECT_NOT_ACTIVE_OR_ID_MISMATCH');
    }
    const projectNumber = projectNumberFromName(project.name);
    if (!projectNumber) throw new Error('PROJECT_NUMBER_MISSING');

    const permissions = await this.requestJson(
      `${CLOUD_RESOURCE_MANAGER_V1}/projects/${encodeURIComponent(requestedProjectId)}:testIamPermissions`,
      {
        accessToken,
        method: 'POST',
        body: { permissions: [REQUIRED_QUOTA_PERMISSION] },
      },
    );
    const allowed = new Set(Array.isArray(permissions.permissions) ? permissions.permissions : []);
    if (!allowed.has(REQUIRED_QUOTA_PERMISSION)) {
      throw new Error('SERVICEUSAGE_SERVICES_USE_MISSING');
    }

    const service = await this.requestJson(
      `${SERVICE_USAGE_V1}/projects/${projectNumber}/services/${GEMINI_SERVICE}`,
      { accessToken },
    );
    if (!service || service.state !== 'ENABLED') {
      throw new Error('GENERATIVE_LANGUAGE_API_NOT_ENABLED');
    }

    await this.requestJson(`${GENERATIVE_LANGUAGE_V1}/models`, {
      accessToken,
      headers: { 'x-goog-user-project': requestedProjectId },
    });

    return Object.freeze({
      serverValidated: true,
      projectId: requestedProjectId,
      projectNumber,
      displayName: project.displayName || null,
      geminiApiEnabled: true,
      serviceUsageUse: true,
      validatedAtMs: Number(this.clock()),
    });
  }
}

module.exports = {
  GEMINI_SERVICE,
  REQUIRED_QUOTA_PERMISSION,
  StudyGoogleAiOAuthProjectDiscoveryValidationV1,
};
