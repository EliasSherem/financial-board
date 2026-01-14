import React from 'react';

const FinSightLogo: React.FC = () => {
  return (
    <svg width="200" height="60" viewBox="0 0 640 200" fill="none" xmlns="http://www.w3.org/2000/svg">
      <defs>
        <style>
          {`
            .word { 
              font-family: 'Inter', 'Poppins', 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; 
              font-weight: 700; 
            }
            .subtle { 
              font-weight: 500; 
            }
          `}
        </style>
      </defs>

      {/* Icon */}
      <g transform="translate(20,20)">
        <rect x="0" y="0" width="160" height="160" rx="22" fill="#2563EB"/>
        <rect x="50" y="88" width="20" height="48" rx="5" fill="#38BDF8"/>
        <rect x="80" y="64" width="20" height="72" rx="5" fill="#22C55E"/>
        <rect x="110" y="36" width="20" height="100" rx="5" fill="#A855F7"/>
        <line x1="18" y1="140" x2="142" y2="140" stroke="#FFFFFF" strokeWidth="8" strokeLinecap="round"/>
        <polyline points="18,120 48,96 88,76 126,48 144,38"
                  fill="none" stroke="#FFFFFF" strokeWidth="10" strokeLinecap="round" strokeLinejoin="round"/>
      </g>

      {/* Wordmark */}
      <text className="word" x="210" y="115" fontSize="76" fill="#FFFFFF">
        Fin<tspan className="subtle" fill="#FFFFFF">Sight</tspan>
      </text>
    </svg>
  );
};

export default FinSightLogo;
