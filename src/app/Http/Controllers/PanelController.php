<?php

namespace App\Http\Controllers;

use Illuminate\View\View;

class PanelController extends Controller
{
    public function index(): View
    {
        return view('panel', ['usuario' => auth()->user()]);
    }
}
