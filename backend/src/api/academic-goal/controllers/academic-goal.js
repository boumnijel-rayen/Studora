'use strict';

const { createOwnedController } = require('../../../utils/ownership');

module.exports = createOwnedController('api::academic-goal.academic-goal', {
  defaultPopulate: { subject: true },
});

