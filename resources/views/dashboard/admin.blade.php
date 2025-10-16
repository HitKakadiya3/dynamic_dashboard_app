<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            Admin Dashboard
        </h2>
    </x-slot>

    <div class="py-12 text-center">
        <h1 class="text-2xl font-bold">Welcome, {{ $user->name }} (Admin)</h1>
        <p>Here you can manage users, view stats, and monitor activity.</p>
    </div>
</x-app-layout>
