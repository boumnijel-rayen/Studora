'use strict';

const GROUP_UID = 'api::study-group.study-group';

async function isMemberOfGroup(strapi, groupId, userId) {
  if (!groupId) return false;
  const group = await strapi.documents(GROUP_UID).findOne({
    documentId: groupId,
    populate: { creator: true, members: true },
  });
  if (!group) return false;
  return (
    group.creator?.id === userId ||
    (group.members || []).some((m) => m.id === userId)
  );
}

module.exports = { isMemberOfGroup };
