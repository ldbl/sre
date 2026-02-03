import { createRouter, createWebHistory } from 'vue-router'
import DashboardView from '../views/DashboardView.vue'

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    {
      path: '/',
      name: 'dashboard',
      component: DashboardView,
    },
    {
      path: '/chaos',
      name: 'chaos',
      component: () => import('../views/ChaosView.vue'),
    },
    {
      path: '/api-explorer',
      name: 'api-explorer',
      component: () => import('../views/ApiExplorerView.vue'),
    },
    {
      path: '/environment',
      name: 'environment',
      component: () => import('../views/EnvironmentView.vue'),
    },
  ],
})

export default router
