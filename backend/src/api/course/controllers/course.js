'use strict';

const { createOwnedController } = require('../../../utils/ownership');

module.exports = createOwnedController('api::course.course', {
  defaultPopulate: { subject: true },
});

