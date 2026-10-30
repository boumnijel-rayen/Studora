'use strict';

const { createOwnedController } = require('../../../utils/ownership');

module.exports = createOwnedController('api::deadline.deadline', {
  defaultPopulate: { subject: true },
});

