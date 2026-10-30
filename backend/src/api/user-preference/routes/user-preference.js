'use strict';

module.exports = {
  routes: [
    {
      method: 'GET',
      path: '/user-preferences/me',
      handler: 'user-preference.findMine',
    },
    {
      method: 'PUT',
      path: '/user-preferences/me',
      handler: 'user-preference.updateMine',
    },
  ],
};

