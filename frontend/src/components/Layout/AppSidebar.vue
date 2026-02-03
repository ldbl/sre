<script setup>
import { RouterLink } from 'vue-router'

const navItems = [
  { name: 'Dashboard', path: '/', icon: '📊' },
  { name: 'Chaos Engineering', path: '/chaos', icon: '💥' },
  { name: 'API Explorer', path: '/api-explorer', icon: '🔍' },
  { name: 'Environment', path: '/environment', icon: '⚙️' },
]
</script>

<template>
  <aside class="w-64 bg-slate-800 border-r border-slate-700 min-h-[calc(100vh-73px)]">
    <nav class="p-4">
      <ul class="space-y-2">
        <li v-for="item in navItems" :key="item.path">
          <RouterLink
            :to="item.path"
            class="flex items-center gap-3 px-4 py-3 rounded-lg text-slate-300 hover:bg-slate-700 hover:text-white transition-colors"
            active-class="bg-slate-700 text-white"
          >
            <span class="text-xl">{{ item.icon }}</span>
            <span>{{ item.name }}</span>
          </RouterLink>
        </li>
      </ul>
    </nav>
  </aside>
</template>
