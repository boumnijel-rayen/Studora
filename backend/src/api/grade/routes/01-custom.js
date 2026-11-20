'use strict';

module.exports = {
  routes: [
    {
      method: 'POST',
      path: '/grades/import-scan',
      handler: 'grade.scanImport',
    },
  ],
};
