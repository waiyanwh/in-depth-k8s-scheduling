# Kubernetes Scheduler Watch

A real-time, terminal-based dashboard for visualizing Kubernetes Scheduling Labs. Built with Python and [Rich](https://github.com/Textualize/rich).

## Features
- **Live Updates**: Refreshes cluster state every second.
- **Node Visualization**: Groups nodes by Role (GPU, Prod, Zone A/B) with capacity indicators.
- **Pod Mapping**: Visualizes running pods with custom icons (e.g., 🧠 for AI models).
- **Pending Queue**: Monitors unscheduled pods and their priority classes.

## Prerequisites
- Python 3
- `kubectl` configured with access to your cluster.
- A terminal with Unicode support (for icons and borders).

## Setup & Installation

It is recommended to use a virtual environment.

1.  **Create a virtual environment**:
    ```bash
    python3 -m venv .venv
    ```

2.  **Activate the environment**:
    ```bash
    source .venv/bin/activate
    ```

3.  **Install dependencies**:
    ```bash
    pip install -r requirements.txt
    ```

## Usage

Run the dashboard script:

```bash
python3 scheduler_watch.py
```

## Troubleshooting

- **Missing Data**: Ensure `kubectl get nodes` and `kubectl get pods` work in your current shell.
- **Display Issues**: If icons don't show up, check your terminal font (Nerd Fonts recommended).
