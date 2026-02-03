<script setup>
import { computed } from 'vue'
import { useBackendStore } from '../../stores/backend'

const backendStore = useBackendStore()

const statusColor = computed(() => {
  switch (backendStore.healthStatus) {
    case 'healthy': return 'bg-green-500'
    case 'not-ready': return 'bg-yellow-500'
    case 'not-live': return 'bg-orange-500'
    default: return 'bg-red-500'
  }
})
</script>

<template>
  <header class="bg-slate-800 border-b border-slate-700">
    <div class="px-6 py-4 flex items-center justify-between">
      <div class="flex items-center gap-4">
        <h1 class="text-2xl font-bold text-white">SRE Control Plane</h1>
        <div class="flex items-center gap-2">
          <div :class="['w-2 h-2 rounded-full', statusColor]"></div>
          <span class="text-sm text-slate-400">{{ backendStore.healthStatus }}</span>
        </div>
      </div>
      <div class="flex items-center gap-4 text-sm text-slate-400">
        <span v-if="backendStore.version">
          {{ backendStore.version.version || 'dev' }}
        </span>
        <span v-if="backendStore.version">
          {{ backendStore.version.commit_short }}
        </span>
      </div>
    </div>
  </header>
</template>
