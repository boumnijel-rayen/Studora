'use strict';

const { createOwnedController } = require('../../../utils/ownership');

module.exports = createOwnedController('api::study-session.study-session', {
  defaultPopulate: { subject: true, task: true },
});

