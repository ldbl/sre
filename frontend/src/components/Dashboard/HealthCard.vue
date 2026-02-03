<script setup>
import { computed } from 'vue'

const props = defineProps({
  title: String,
  status: Boolean,
  loading: Boolean,
})

const statusClass = computed(() => {
  if (props.loading) return 'bg-slate-700 text-slate-400'
  return props.status ? 'bg-green-900/50 text-green-400' : 'bg-red-900/50 text-red-400'
})

const statusIcon = computed(() => {
  if (props.loading) return '⏳'
  return props.status ? '✅' : '❌'
})
</script>

<template>
  <div :class="['rounded-lg border p-6 transition-all', statusClass]">
    <div class="flex items-center justify-between">
      <h3 class="text-lg font-semibold">{{ title }}</h3>
      <span class="text-3xl">{{ statusIcon }}</span>
    </div>
    <div class="mt-4">
      <p class="text-sm font-medium">
        {{ loading ? 'Checking...' : (status ? 'OK' : 'Failed') }}
      </p>
    </div>
  </div>
</template>
