# Studora

Studora is a mobile app that helps students organise and follow their studies, from their schedule and grades to study sessions, study groups and shared housing. The interface is in French.

## Features

| Module | What students can do |
|---|---|
| **Account** | Register, log in, reset a password, edit their profile and change settings |
| **Schedule** | Manage courses and deadlines, and see notifications |
| **Grades** | Record grades by subject, set academic goals and simulate results |
| **Study** | Plan study sessions and tasks, use a Pomodoro timer and review their history |
| **Groups** | Create or join study groups with an invitation code, and chat with members |
| **Colocation** | Create or join a shared home with an invitation key, then manage roommates, chores, shared expenses and balances, and chat together |

## Tech stack

| Part | Technology |
|---|---|
| **Mobile app** | Flutter (Dart SDK `^3.8.1`) |
| **State management** | Riverpod |
| **Navigation** | go_router |
| **Charts** | fl_chart |
| **Backend** | Strapi 5 (Node.js up to version 22) |
| **Database** | PostgreSQL on the shared server, SQLite for local development |

## Project structure

```text
lib/
  app/           App setup and routing
  core/          Design system, models, network, providers and shared services
  features/      One folder per module: auth, schedule, grades, study, groups, roommates
backend/
  config/        Strapi settings: server, database, plugins
  src/api/       Data models, controllers and routes
  src/utils/     Shared backend logic
  src/index.js   Role permissions
test/            Flutter tests
docs/            Deployment guide
render.yaml      Render service settings
```

## Getting started

You need Flutter and Android Studio. The app uses the shared server by default, so you don't need to run the backend.

1. Clone the repository and install the dependencies:

   ```bash
   flutter pub get
   ```

2. Start an Android emulator, then press **Run** in Android Studio.
3. If the app can't connect, see [Live Remote Server](#live-remote-server).

### Running the backend locally

You only need this for backend work. Your local Strapi stores its data in a SQLite file and doesn't touch the shared database.

1. Start Strapi:

   ```bash
   cd backend
   npm install        # first time only
   npm run setup:env  # first time only
   npm run develop
   ```

2. Open the local admin panel at http://localhost:1337/admin.
3. Run the app against it, on the Android emulator:

   ```bash
   flutter run --dart-define=STRAPI_URL=http://10.0.2.2:1337
   ```

On Windows, if PowerShell blocks `npm`, use `npm.cmd` instead.

### Tests

```bash
flutter test
```

```bash
cd backend
npm test
```

### Adding dependencies

New Flutter dependencies must be approved by the project lead.

## Live Remote Server

The team shares one backend and one set of data, hosted online. Strapi runs on Render and stores its data in a PostgreSQL database on Neon.

| | |
|---|---|
| **Shared server** | https://studora-api-lz9u.onrender.com |
| **Admin panel** | https://studora-api-lz9u.onrender.com/admin |
| **Wake-up / health page** | https://studora-api-lz9u.onrender.com/_health |

If the app can't connect, the server is probably asleep. Open the [wake-up page](https://studora-api-lz9u.onrender.com/_health), wait for it to finish loading (the page stays blank), then try again.

### How it fits together

```text
Flutter app  --HTTPS-->  Strapi on Render  --SSL-->  PostgreSQL on Neon
(the screens)            (the rules)                 (the data)
```

When someone sends a chat message, for example:

1. The app sends the message to Strapi.
2. Strapi checks that the person is logged in and belongs to that colocation.
3. Strapi saves the message in Neon.

The app never connects to Neon directly, and it never contains database passwords or Strapi secrets.

#### The role of Strapi

Strapi is the backend, the layer between the app and the database. It handles:

- **The API:** the addresses the app calls, such as `/api/colocations/mine`.
- **Accounts:** registration, login and session tokens.
- **Rules and permissions:** who can read or change what. Custom logic is in `backend/src/api/` and `backend/src/utils/`, and role permissions are set in `backend/src/index.js`.
- **The data structure:** each `schema.json` file describes a table. Strapi updates the database to match when it starts.
- **The admin panel:** a website for viewing and editing data.

#### The role of Render

Render runs Strapi on the internet. It reads `render.yaml`, builds the backend from GitHub and gives it a public HTTPS address. Render's disk is temporary, so nothing permanent is stored there.

#### The role of Neon

Neon hosts the PostgreSQL database, where users, colocations, expenses, chores, messages and everything else the app saves are kept. Because the data lives in Neon, it survives Render restarts and redeploys. Only Strapi connects to it, using the `DATABASE_*` settings stored in Render.

### Limitations

These are the free plan limits as of October 2026. Providers can change them, so check their pricing pages.

#### Render (free plan)

| Limit | What it means for us |
|---|---|
| Sleeps after 15 minutes without traffic | The next request can take up to a minute to wake it |
| 750 instance hours a month; sleeping doesn't count | If they run out, the server stops until next month |
| 512 MB of memory | Strapi used about 300 MB in a light local test; heavy use could crash and restart it |
| Temporary disk | Uploaded files would be lost on restart, so file uploads need external storage |

The app gives up on a request after 15 seconds, which is shorter than the wake-up time. That's why the first attempt can fail and the wake-up page helps.

#### Neon (free plan)

| Limit | What it means for us |
|---|---|
| 0.5 GB of storage per project | Plenty for testing, but not for large amounts of data |
| 100 compute hours and 5 GB of network transfer per project each month | Reaching a limit pauses the database until next month |
| Suspends after 5 minutes without activity | The first request afterwards can be a little slower |

#### This setup in general

- **For development and testing, not production:** the sleep time and limits aren't suited to real users.
- **Shared data:** everyone sees the same database, and a mistake by one person affects the whole team.
- **No automatic backups from us:** don't rely on this database for anything you can't lose. Export the data before important demos.
- **Test data:** accounts ending in `@example.test` were created by API tests and can be deleted in the admin panel.

### Admin panel

Log in at the [admin panel](https://studora-api-lz9u.onrender.com/admin) and open **Content Manager** to view or edit data. It may not show changes made from the app until you reload the page with **F5**.

The admin account is separate from the app's user accounts. Share it only with people who need it.

### Changing the database structure

The Content-Type Builder is turned off on the shared server, so structure changes go through the code:

1. Run Strapi locally with `npm run develop`.
2. Change the data model in the Content-Type Builder. This updates the `schema.json` files.
3. If you added an API endpoint, add its permission in `backend/src/index.js`.
4. Update and test the Flutter code that uses it.
5. Merge into the branch Render deploys. Render redeploys, and Strapi updates the Neon tables when it starts.

**Be careful:**

- Adding fields or tables keeps existing data.
- Renaming or deleting a field can permanently lose that field's data, because Strapi treats a rename as deleting the old field and adding a new one. Back up first. Neon can also copy the database into a branch.
- **Never run `npm run develop` against Neon.** It would apply your local structure directly to the shared database.

### Deployment

- **Deployed branch:** whichever branch is selected in the Render service's **Settings**. Pushing to it redeploys the server, so only push tested code.
- **Setup from scratch:** see [docs/deploiement-render-neon.md](docs/deploiement-render-neon.md).
- **Secrets:** they stay in Render's **Environment** page. Never commit `backend/.env` or put secrets in the Flutter app.

### Troubleshooting

| Problem | What to do |
|---|---|
| The app can't connect | Open the wake-up page, wait for it to load and retry. The server may also be redeploying, so check Render |
| A new record isn't in the admin list | Reload the page with **F5** |
| The deploy fails with `password authentication failed` | Copy the password from Neon again and update `DATABASE_PASSWORD` in Render |
| The server stays down at the start of a session | Check the **Logs** in Render and the usage limits in Render and Neon |
| An invitation key says it belongs to another module | Colocation keys and study group keys are separate, so enter it in the right module |
