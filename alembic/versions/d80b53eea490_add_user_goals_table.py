"""add_user_goals_table

Revision ID: d80b53eea490
Revises: 5c1536d7be4e
Create Date: 2025-03-25 00:56:28.145178

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = 'd80b53eea490'
down_revision: Union[str, None] = '5c1536d7be4e'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade():
    # Drop the table if it exists (to handle the duplicate table error)
    op.execute('DROP TABLE IF EXISTS goals CASCADE')
    
    # Create the goals table
    op.create_table('goals',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('goal_type', sa.String(), nullable=False),
        sa.Column('target_value', sa.Float(), nullable=False),
        sa.Column('current_value', sa.Float(), nullable=True),
        sa.Column('start_date', sa.Date(), nullable=False),
        sa.Column('target_date', sa.Date(), nullable=True),
        sa.Column('is_completed', sa.Boolean(), server_default='false', nullable=False),
        sa.Column('created_at', sa.DateTime(), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_goals_id'), 'goals', ['id'], unique=False)


def downgrade():
    op.drop_index(op.f('ix_goals_id'), table_name='goals')
    op.drop_table('goals')