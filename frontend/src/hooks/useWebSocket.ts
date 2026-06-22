import { useEffect, useRef, useCallback } from 'react';

interface OddsData {
  matchId: string;
  odds: { home: number; draw: number; away: number };
}

interface BalanceData {
  balance: number;
}

interface UseWebSocketOptions {
  onOddsUpdate?: (data: OddsData) => void;
  onBalanceUpdate?: (data: BalanceData) => void;
  onOddsSnapshot?: (data: { matches: OddsData[] }) => void;
}

export function useWebSocket(token: string | null, options: UseWebSocketOptions) {
  const wsRef = useRef<WebSocket | null>(null);
  const retryDelayRef = useRef(1000);
  const mountedRef = useRef(true);
  const retryTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const optionsRef = useRef(options);
  optionsRef.current = options;

  const connect = useCallback(() => {
    if (!token || !mountedRef.current) return;

    const wsProtocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const ws = new WebSocket(`${wsProtocol}//${window.location.host}/ws?token=${token}`);
    wsRef.current = ws;

    ws.onopen = () => {
      retryDelayRef.current = 1000;
    };

    ws.onmessage = (event) => {
      try {
        const msg = JSON.parse(event.data);
        if (msg.type === 'odds_update' && optionsRef.current.onOddsUpdate) {
          optionsRef.current.onOddsUpdate(msg.data);
        } else if (msg.type === 'balance_update' && optionsRef.current.onBalanceUpdate) {
          optionsRef.current.onBalanceUpdate(msg.data);
        } else if (msg.type === 'odds_snapshot' && optionsRef.current.onOddsSnapshot) {
          optionsRef.current.onOddsSnapshot(msg.data);
        }
      } catch {
        // Ignore malformed messages
      }
    };

    ws.onclose = () => {
      if (!mountedRef.current) return;
      const delay = Math.min(retryDelayRef.current, 30000);
      retryTimerRef.current = setTimeout(() => {
        retryDelayRef.current = Math.min(retryDelayRef.current * 2, 30000);
        connect();
      }, delay);
    };

    ws.onerror = () => {
      ws.close();
    };
  }, [token]);

  useEffect(() => {
    mountedRef.current = true;
    connect();

    return () => {
      mountedRef.current = false;
      if (retryTimerRef.current) {
        clearTimeout(retryTimerRef.current);
      }
      if (wsRef.current) {
        wsRef.current.onclose = null;
        wsRef.current.close();
      }
    };
  }, [connect]);
}
