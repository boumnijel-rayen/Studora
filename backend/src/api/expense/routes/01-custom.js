'use strict';

module.exports = {
  routes: [
    {
      method: 'POST',
      path: '/expenses/settle',
      handler: 'expense.settle',
    },
  ],
};

