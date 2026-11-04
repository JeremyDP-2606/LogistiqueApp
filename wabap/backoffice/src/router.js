import { createRouter, createWebHistory } from "vue-router";
import DrawerView from "@/views/DrawerView.vue";
import LoginView from "@/views/LoginView.vue";
import MissionsView from "@/views/MissionsView.vue";
import MissionView from "@/views/MissionView.vue";
import TourneeView from "@/views/TourneeView.vue";
import ColisView from "@/views/ColisView.vue";
import MissionEditView from "@/views/MissionEditView.vue";
import SubscribersView from "@/views/SubscribersView.vue";
import SubscriberView from "@/views/SubscriberView.vue";
import UsersView from "@/views/UsersView.vue";
import UserView from "@/views/UserView.vue";
import UserEditView from "@/views/UserEditView.vue";
import AddSubscriberView from "@/views/AddSubscriberView.vue";
import StatisticsView from "@/views/StatisticsView.vue";
import CoursesView from "@/views/CoursesView.vue";
import CourseView from "@/views/CourseView.vue";
import TarifsView from "@/views/TarifsView.vue";
import { isUserAuthenticated, isAuthorized, isAdmin } from "@/util/auth";
import { Auth } from "@/util/cognito";

const routes = [
  {
    path: "/login",
    name: "Login",
    component: LoginView,
  },
  {
    path: "/",
    component: DrawerView,
    children: [
      {
        path: "/missions",
        name: "Missions",
        component: MissionsView,
      },
      {
        path: "/missions/create",
        name: "MissionCreate",
        component: MissionEditView,
      },
      {
        path: "/mission/:id",
        name: "Mission",
        component: MissionView,
      },
      {
        path: "/mission/edit/:id",
        name: "MissionEdit",
        component: MissionEditView,
      },
      {
        path: "/tournee/:id",
        name: "Tournee",
        component: TourneeView,
      },
      {
        path: "/colis/:id",
        name: "Colis",
        component: ColisView,
      },
      {
        path: "/subscribers",
        name: "Abonnés",
        component: SubscribersView,
      },
      {
        path: "/subscriber/:id",
        name: "Abonné",
        component: SubscriberView,
      },
      {
        path: "/addsubscriber",
        name: "Ajout Abonnés",
        component: AddSubscriberView,
      },
      {
        path: "/courses",
        name: "Courses",
        component: CoursesView,
      },
      {
        path: "/course/:id",
        name: "Course",
        component: CourseView,
      },
      {
        path: "/tarifs",
        name: "Tarifs",
        component: TarifsView,
      },
      {
        path: "/statistics",
        name: "Statistiques",
        component: StatisticsView,
      },
      {
        path: "/users",
        name: "Utilisateurs",
        component: UsersView,
      },
      {
        path: "/user/create",
        name: "UserCreate",
        component: UserEditView,
      },
      {
        path: "/user/:id",
        name: "Utilisateur",
        component: UserView,
      },
      {
        path: "/user/edit/:id",
        name: "UserEdit",
        component: UserEditView,
      },
    ],
  },
];

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL || '/'),
  routes,
});

router.beforeEach(async (to, from, next) => {
  const isAuthenticated = await isUserAuthenticated();
  const isOk = await isAuthorized();
  const isAdmi = await isAdmin();

  if (to.path !== "/login" && !isAuthenticated) {
    next("/login");
  } else if ( to.path !== "/login" && isAuthenticated && !isOk) {
    await Auth.signOut();
    next("/login");
  } else if ((to.path === "/" || to.path === "/login") && isAuthenticated) {
    next("/missions");
  } else if ((to.path.includes("edit") || to.path.includes("create") || to.path === "/tarifs") && !isAdmi) {
    next("/missions");
  } else {
    next();
  }
});

export default router;
