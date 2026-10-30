'use strict';

const { createOwnedController } = require('../../../utils/ownership');

module.exports = createOwnedController('api::study-task.study-task', {
  defaultPopulate: { subject: true },
});

