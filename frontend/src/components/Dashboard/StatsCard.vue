<script setup>
defineProps({
  title: String,
  value: [String, Number],
  icon: String,
  trend: String,
})
</script>

<template>
  <div class="bg-slate-800 rounded-lg border border-slate-700 p-6">
    <div class="flex items-center justify-between mb-2">
      <span class="text-sm text-slate-400">{{ title }}</span>
      <span class="text-2xl">{{ icon }}</span>
    </div>
    <div class="text-3xl font-bold text-white">{{ value }}</div>
    <div v-if="trend" class="mt-2 text-sm text-slate-400">
      {{ trend }}
    </div>
  </div>
</template>
