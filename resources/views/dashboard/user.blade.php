<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            User Dashboard
        </h2>
    </x-slot>

    <div class="py-12 text-center">
        <h1 class="text-2xl font-bold">Welcome, {{ $user->name }}</h1>
        <p>Here you can view your profile, track progress, and manage tasks.</p>
    </div>
</x-app-layout>
