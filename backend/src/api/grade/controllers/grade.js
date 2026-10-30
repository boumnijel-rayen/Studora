'use strict';

const { createOwnedController } = require('../../../utils/ownership');

module.exports = createOwnedController('api::grade.grade', {
  defaultPopulate: { subject: true },
});

