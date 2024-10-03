# Saved segments

## Definitions

| Term | Definition |
|------|------------|
| **Segment Owner** | Usually the user who authored the segment, but can change over time |
| **Personal Segment** | A segment that has personal flag set as true and the user is the segment owner |
| **Personal Segments of Other Users** | A segment that has personal flag set as true and the user is not the segment owner |
| **Site Segment** | A segment that has personal flag set to false |
| **Segment Contents** | A list of filters |

## Capabilities

| Capability | Public | Viewer | Admin | Owner | Super Admin |
|------------|--------|--------|-------|-------|-------------|
| Can view data filtered by any segment they know the ID of | ✅ | ✅ | ✅ | ✅ | ✅ |
| Can make API requests filtered by any segment they know the ID of |  | ✅ | ✅ | ✅ | ✅ |
| Can create personal segments |  | ✅ | ✅ | ✅ | ✅ |
| Can set personal segments to be site segments |  | ❓ | ✅ | ✅ | ✅ |
| Can set site segments to be personal segments |  | ❓ | ✅ | ✅ | ✅ |
| Can see list of personal segments |  | ✅ | ✅ | ✅ | ✅ |
| Can see list of site segments | ✅ | ✅ | ✅ | ✅ | ✅ |
| Can see contents of personal segments |  | ✅ | ✅ | ✅ | ✅ |
| Can see contents of site segments | ❓ | ❓ | ✅ | ✅ | ✅ |
| Can edit personal segments |  | ✅ | ✅ | ✅ | ✅ |
| Can edit site segments |  | ❓ | ✅ | ✅ | ✅ |
| Can delete personal segments |  | ✅ | ✅ | ✅ | ✅ |
| Can delete site segments |  | ❓ | ✅ | ✅ | ✅ |
| Can list personal segments of other users [1] |  |  | ❓ | ❓ | ❓ |
| Can see contents of personal segments of other users [1] |  |  | ❓ | ❓ | ❓ |
| Can edit personal segments of other users [1] |  |  | ❓ | ❓ | ❓ |
| Can delete personal segments of other users [1] |  |  | ❓ | ❓ | ❓ |

### Notes

__[1]__: maybe needed for elevated roles to be able to take control of segments of deleted / inactive / vacationing users, or to toggle whether such segments are site segments or not

## Segment lifecycle

| Action | Outcome |
|--------|---------|
| A user* selects filters that constitute the segment, chooses name, clicks save | Personal segment created (with user as segment owner) |
| A user* views the contents of an existing segment, chooses name, clicks save as | Personal segment created (with user as segment owner) |
| Segment owner* clicks edit segment, changes segment name or adds/removes/edits filters, clicks save | Segment updated |
| Segment owner* or another user* toggles personal segment to be site segment | Segment elevated to be a site segment |
| Segment owner* or another user* toggles site segment to be a personal segment | Segment de-elevated to be a personal segment |
| Any user* except the segment owner opens the segment for editing and clicks save, with or without changes | Segment updated (with editor becoming the new segment owner) |
| Segment owner* deletes segment | Segment deleted |
| Any user* except the segment owner deletes segment | Segment deleted |
| Site deleted | Segment autodeleted |
| Segment owner is removed from site or deleted from Plausible | If personal segment, segment autodeleted; if site segment, nothing happens |
| Any user* updates goal name, if site has any segments with "is goal ..." filters for that goal | Segment autoupdated |
| Plausible engineer updates filters schema in backwards incompatible way | Segment autoupdated/automigrated |

### Notes

__*__: if the user has that particular capability

## Schema

| Field | Type | Constraints | Comment |
|-------|------|-------------|---------|
| :id | :bigint | null: false | |
| :name | :string | null: false | |
| :personal | :boolean | default: true, null: false | Needed to distinguish between segments we can clean up automatically and segments that need to remain stable over time |
| :segment_data | :map | null: false | Contains the filters array at "filters" key |
| :site_id | references(:sites) | on_delete: :delete_all, null: false | |
| :owner_id | references(:users) | on_delete: :nothing, null: false | Used to display author info without repeating author name and email in the database |
| timestamps() | | | Inserted_at, updated_at fields |

## API

[lib/plausible_web/router.ex](../../plausible_web/router.ex)