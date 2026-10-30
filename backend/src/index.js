'use strict';

const PUBLIC_PERMISSIONS = [
  'plugin::users-permissions.auth.callback',
  'plugin::users-permissions.auth.register',
  'plugin::users-permissions.auth.forgotPassword',
  'plugin::users-permissions.auth.resetPassword',
  'api::app-setting.app-setting.find',
];

const AUTHENTICATED_PERMISSIONS = [
  ...PUBLIC_PERMISSIONS,
  'plugin::users-permissions.user.me',
  'plugin::users-permissions.user.updateMe',
  'plugin::users-permissions.user.update',
  'plugin::users-permissions.auth.changePassword',
  'api::user-preference.user-preference.findMine',
  'api::user-preference.user-preference.updateMine',
  'api::subject.subject.find',
  'api::subject.subject.findOne',
  'api::subject.subject.create',
  'api::subject.subject.update',
  'api::subject.subject.delete',
  'api::course.course.find',
  'api::course.course.findOne',
  'api::course.course.create',
  'api::course.course.update',
  'api::course.course.delete',
  'api::deadline.deadline.find',
  'api::deadline.deadline.findOne',
  'api::deadline.deadline.create',
  'api::deadline.deadline.update',
  'api::deadline.deadline.delete',
  'api::app-notification.app-notification.find',
  'api::app-notification.app-notification.findOne',
  'api::app-notification.app-notification.create',
  'api::app-notification.app-notification.update',
  'api::app-notification.app-notification.delete',
  'api::app-notification.app-notification.markAllRead',
  'api::study-task.study-task.find',
  'api::study-task.study-task.findOne',
  'api::study-task.study-task.create',
  'api::study-task.study-task.update',
  'api::study-task.study-task.delete',
  'api::study-session.study-session.find',
  'api::study-session.study-session.findOne',
  'api::study-session.study-session.create',
  'api::study-session.study-session.update',
  'api::study-session.study-session.delete',
  'api::grade.grade.find',
  'api::grade.grade.findOne',
  'api::grade.grade.create',
  'api::grade.grade.update',
  'api::grade.grade.delete',
  'api::academic-goal.academic-goal.find',
  'api::academic-goal.academic-goal.findOne',
  'api::academic-goal.academic-goal.create',
  'api::academic-goal.academic-goal.update',
  'api::academic-goal.academic-goal.delete',
  'api::study-group.study-group.find',
  'api::study-group.study-group.findOne',
  'api::study-group.study-group.create',
  'api::study-group.study-group.delete',
  'api::study-group.study-group.joinByCode',
  'api::group-message.group-message.find',
  'api::group-message.group-message.create',
  'api::group-activity.group-activity.find',
  'api::group-activity.group-activity.create',
  'api::roommate-member.roommate-member.find',
  'api::roommate-member.roommate-member.findOne',
  'api::roommate-member.roommate-member.create',
  'api::roommate-member.roommate-member.update',
  'api::roommate-member.roommate-member.delete',
  'api::chore.chore.find',
  'api::chore.chore.findOne',
  'api::chore.chore.create',
  'api::chore.chore.update',
  'api::chore.chore.delete',
  'api::expense.expense.find',
  'api::expense.expense.findOne',
  'api::expense.expense.create',
  'api::expense.expense.update',
  'api::expense.expense.delete',
  'api::expense.expense.settle',
];

async function ensureRolePermissions(strapi, roleType, actions) {
  const role = await strapi.db
    .query('plugin::users-permissions.role')
    .findOne({ where: { type: roleType } });
  if (!role) return;

  for (const action of actions) {
    const existing = await strapi.db
      .query('plugin::users-permissions.permission')
      .findOne({ where: { role: role.id, action } });

    if (!existing) {
      await strapi.db.query('plugin::users-permissions.permission').create({
        data: { role: role.id, action },
      });
    }
  }
}

module.exports = {
  register() {},

  async bootstrap({ strapi }) {
    await ensureRolePermissions(strapi, 'public', PUBLIC_PERMISSIONS);
    await ensureRolePermissions(strapi, 'authenticated', AUTHENTICATED_PERMISSIONS);
  },
};

