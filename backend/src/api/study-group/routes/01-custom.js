'use strict';

module.exports = {
  routes: [
    {
      method: 'POST',
      path: '/study-groups/join',
      handler: 'study-group.joinByCode',
    },
  ],
};

